# adapted from https://github.com/adetante/ethereum-nginx-proxy
local cjson = require('cjson')

local MAX_RPCS = 20

local function empty(s)
  return s == nil or s == ''
end

local function split(s)
  local res = {}
  local i = 1
  for v in string.gmatch(s, "([^,]+)") do
    res[i] = v
    i = i + 1
  end
  return res
end

local function contains(arr, val)
  for i, v in ipairs (arr) do
    if v == val then
      return true
    end
  end
  return false
end

local function is_array(table)
    local max = 0
    local count = 0
    for k, v in pairs(table) do
        if type(k) == "number" then
            if k > max then max = k end
            count = count + 1
        else
            return -1
        end
    end
    if max > count * 2 then
        return -1
    end

    return max
end

-- parse conf
local blacklist, whitelist = nil
if not empty(ngx.var.jsonrpc_blacklist) then
  blacklist = split(ngx.var.jsonrpc_blacklist)
end
if not empty(ngx.var.jsonrpc_whitelist) then
  whitelist = split(ngx.var.jsonrpc_whitelist)
end

-- check conf
if blacklist ~= nil and whitelist ~= nil then
  ngx.log(ngx.ERR, 'invalid conf: jsonrpc_blacklist and jsonrpc_whitelist are both set')
  ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  return
end

-- get request content
ngx.req.read_body()

-- try to parse the body as JSON
local success, body = pcall(cjson.decode, ngx.var.request_body);
if not success then
  ngx.log(ngx.ERR, 'invalid JSON request')
  ngx.exit(ngx.HTTP_BAD_REQUEST)
  return
end

local method = body['method']

local rpcs = {}
local num_rpcs = 0

if empty(method) then
   -- possibly a list of RPCs
   num_rpcs = is_array(body)
   if num_rpcs <= 0 then
      ngx.log(ngx.ERR, "jsonrpc body is neither an object nor an array")
      ngx.exit(ngx.HTTP_BAD_REQUEST)
      return
   end

   if num_rpcs > MAX_RPCS then
      ngx.log(ngx.ERR, "Too many RPC requests (" .. num_rpcs .. ")")
      ngx.exit(ngx.HTTP_BAD_REQUEST)
      return
   end

   rpcs = body
else
   -- single RPC
   rpcs[0] = body
   num_rpcs = 1
end

for i, msg in pairs(rpcs) do
   local method = nil
   local version = nil

   if msg == nil or type(msg) ~= "table" then
      ngx.log(ngx.ERR, 'Invalid RPC entry at ' .. i)
      ngx.exit(ngx.HTTP_BAD_REQUEST)
      return
   end

   -- check we have a method and a version
   method = msg['method']
   version = msg['jsonrpc']

   if empty(version) then
      version = "1.0"
   end

   if empty(method) then
      ngx.log(ngx.ERR, 'no method jsonrpc attribute at ' .. i)
      ngx.exit(ngx.HTTP_BAD_REQUEST)
      return
   end

   -- check the version is supported
   if version ~= "1.0" and version ~= "2.0" then
      ngx.log(ngx.ERR, 'jsonrpc version not supported: ' .. version)
      ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
      return
   end

   -- if whitelist is configured, check that the method is whitelisted
   if whitelist ~= nil then
      if not contains(whitelist, method) then
         ngx.log(ngx.ERR, 'jsonrpc method is not whitelisted: ' .. method)
         ngx.exit(ngx.HTTP_FORBIDDEN)
        return
      end
   end

   -- if blacklist is configured, check that the method is not blacklisted
   if blacklist ~= nil then
      if contains(blacklist, method) then
         ngx.log(ngx.ERR, 'jsonrpc method is blacklisted: ' .. method)
         ngx.exit(ngx.HTTP_FORBIDDEN)
         return
      end
   end
end

return

