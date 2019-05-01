-- configuration
buckets_path = "/tmp/buckets.txt"       -- file on disk where the bucket sizes can be found.  Format is lines of "ADDRESS NUM_BYTES"
shared_table = "throttled_addresses"    -- must match lua_shared_dict in nginx.conf
min_size = 512 * 1024 * 1024            -- start throttling if the bucket is at least this big
min_delay = 0.5                         -- minimum throttle penalty
max_delay = 60                          -- maximum throttle penalty
delay_per_mb = 0.01                     -- penalty per MB over the minimum-throttle size

-- input: path to the file with the throttle list
-- output: none
-- side-effect: populate table with entries in the file
local function load_throttle_list(path, table)
   local line_pattern = "(%w+)%s+(%d+)"

   -- check for existence
   local fd = io.open(path, "rb")
   if fd == nil then
      ngx.log(ngx.STDERR, "Could not read bucket sizes file at '" .. path .. "'")
      return table
   end
   fd:close()

   for l in io.lines(path) do
      if string.find(l, line_pattern) ~= nil then
         for addr, size in string.gmatch(l, line_pattern) do
            -- ngx.log(ngx.STDERR, "Bucket '" .. addr .. "' has " .. size .. " bytes")
            table[addr] = tonumber(size)
            table[addr .. "-last"] = 0
         end
      end
   end
end

-- input: the bucket size
-- output: the delay to wait
-- side-effect: none
local function calculate_delay(bucket_size)
   if bucket_size >= min_size then
      local delay = min_delay + delay_per_mb * ((bucket_size - min_size) / (1024 * 1024))
      if delay >= max_delay then
         delay = max_delay
      end
      return delay
   else
      return 0
   end
end

-- input: the bucket table and the ID of the bucket
-- output: none
-- side-effect: terminate the connection if the client is requesting too frequently, and update bucket_table.
local function throttle(bucket_table, bucket_id)
   local bucket_size = bucket_table[bucket_id]
   local last_request_time = bucket_table[bucket_id .. "-last"]
   local now = ngx.now()
   if bucket_size ~= nil then
      local delay = calculate_delay(bucket_size)
      if delay > 0 then 
         if now < last_request_time + delay then
            -- tell the client to back off
            ngx.log(ngx.STDERR, "Throttle " .. bucket_id .. " for " .. delay .. " seconds")
            ngx.exit(ngx.HTTP_TOO_MANY_REQUESTS)
         else
            -- allow the request, but deny the next one until the delay passes
            bucket_table[bucket_id .. "-last"] = now + delay
         end
      end
   end
end

-- only handle POST 
local method = ngx.req.get_method()
if method ~= "POST" then
   ngx.exit(ngx.HTTP_BAD_REQUEST)
   return
end

-- get address from location regex
local gaia_address = ngx.var[2]
local bucket_table = ngx.shared[shared_table]

-- instantiated? check the shared dict 
if bucket_table["instantiated"] ~= "instantiated" then
   load_throttle_list(buckets_path, bucket_table)
   bucket_table["instantiated"] = "instantiated"
   ngx.log(ngx.STDERR, "Instantiated throttle list")
end

if bucket_table[gaia_address] ~= nil then
   throttle(bucket_table, gaia_address)
end

return 

