#!/bin/dash

# usage: haproxy-reload.sh [/path/to/haproxy.cfg [/path/to/haproxy.cfg.in]]
# script to be run periodically that regenerates /etc/haproxy/haproxy.cfg from our backend bitcoind servers.

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
HAPROXY_CFG_IN="/etc/haproxy/haproxy.cfg.in"

if [ "$#" -ge 1 ]; then 
   HAPROXY_CFG=$1
   shift 1
fi

if [ "$#" -ge 1 ]; then 
   HAPROXY_CFG_IN=$1
   shift 1
fi

EC2_TMPFILE=/tmp/bitcoind-vms.json
trap "rm -f \"$EC2_TMPFILE\"" 0 1 2 3 15

# print out the "server BACKEND_NAME BACKEND_IP" lines of an haproxy config file,
# by querying Amazon EC2 for the VMs and using the public IP address for the BACKEND_IP
# and the instance name for the BACKEND_NAME.
# $1   Temporary file to store the EC2 json
print_backends() {

   local ec2_tmpfile
   
   ec2_tmpfile=$1

   # find all bitcoind HAProxy backends that are running
   aws ec2 describe-instances --filters "Name=tag-key,Values=haproxy" "Name=tag-value,Values=1" "Name=instance-state-name,Values=running" > $ec2_tmpfile

   # get their public IP addresses and instance names...
   cat $ec2_tmpfile | jq '.Reservations[].Instances[].PublicIpAddress' | \
   while read public_ip; do

      if [ "$public_ip" = "null" ]; then 
         continue
      fi

      # strip quotes
      public_ip=${public_ip##\"}
      public_ip=${public_ip%%\"}

      # find associated instance name 
      jq_instance=$(printf '.Reservations[].Instances[] | select(.PublicIpAddress=="%s").Tags[] | select(.Key == "Name")["Value"]' $public_ip)
      instance_name=$(cat $EC2_TMPFILE | jq "$jq_instance")

      if [ -z "$instance_name" -o "$instance_name" = "null" ]; then 
         echo >&2 "WARN: failed to look up instance name of $public_ip"
         continue 
      fi

      # strip quotes 
      instance_name=${instance_name##\"}
      instance_name=${instance_name%%\"}

      echo -n "   server $instance_name $public_ip\\\n"
   done

   rm -f "$ec2_tmpfile"
}

# what's the original contents?
sha256_before=$(sha256sum "$HAPROXY_CFG" || echo "")

cat "$HAPROXY_CFG_IN" | \
   sed -e "s~@HAPROXY_BACKENDS@~$(print_backends $EC2_TMPFILE)~g;" > "$HAPROXY_CFG"

sha256_after=$(sha256sum "$HAPROXY_CFG")

if [ "$sha256_before" != "$sha256_after" ]; then 
   # signal haproxy to reload
   /etc/init.d/haproxy reload
fi

exit 0

