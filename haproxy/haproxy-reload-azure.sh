#!/bin/dash

# usage: haproxy-reload.sh [/path/to/haproxy.cfg [/path/to/haproxy.cfg.in]]
# script to be run periodically that regenerates /etc/haproxy/haproxy.cfg from our backend bitcoind servers.

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"
HAPROXY_CFG_IN="/etc/haproxy/haproxy.cfg.in"
HAPROXY_ERRORS="/etc/haproxy/haproxy.errlog"

SUBSCRIPTION="3405e4b9-253a-450d-8f45-8461c577f78b"
RESOURCE_GROUP="bitcoind"
LOADBALANCE_TAG="bitcoind_loadbalance"

if [ "$#" -ge 1 ]; then 
   HAPROXY_CFG=$1
   shift 1
fi

if [ "$#" -ge 1 ]; then 
   HAPROXY_CFG_IN=$1
   shift 1
fi

VM_TMPFILE=/tmp/bitcoind-vms.json
NIC_TMPFILE=/tmp/bitcoind-nics.json
IPADDR_TMPFILE=/tmp/bitcoind-ipaddrs.json
# trap "rm -f \"$AZURE_TMPFILE\" \"$NIC_TMPFILE\" \"$IPADDR_TMPFILE\"" 0 1 2 3 15

# print out the "server BACKEND_NAME BACKEND_IP" lines of an haproxy config file,
# by querying Azure for the VMs and using the public IP address for the BACKEND_IP
# and the instance name for the BACKEND_NAME.
# $1   Temporary file to store the VM json
# $2   Temporary file to store the NIC json
# $3   Temporary file to store the IP address JSON
print_backends() {

   local vm_tmpfile nic_tmpfile ipaddr_tmpfile
   
   vm_tmpfile="$1"
   nic_tmpfile="$2"
   ipaddr_tmpfile="$3"

   # find all VMs
   azure vm list --json > "$vm_tmpfile"
   rc=$?
 
   if [ $rc -ne 0 ]; then 
      return $rc
   fi

   # select the VMs that are tagged with $LOADBALANCE_TAG
   # get their public IP addresses and instance names...
   cat "$vm_tmpfile" | jq ".[] | .name" | \
   while read vm_name; do

      # strip quotes
      vm_name="${vm_name##\"}"
      vm_name="${vm_name%%\"}"

      nic_path="$(cat "$vm_tmpfile" | jq ".[] | select(.name == \"$vm_name\")  | select(.tags.$LOADBALANCE_TAG == \"1\") | .networkProfile.networkInterfaces[0].id")"
      if [ -z "$nic_path" ]; then 
         continue
      fi
      
      # strip quotes
      nic_path=${nic_path##\"}
      nic_path=${nic_path%%\"}

      nic_name="$(basename "$nic_path")"

      # look up the NIC
      azure network nic show "$RESOURCE_GROUP" "$nic_name" --json > "$nic_tmpfile"
      rc=$?
 
      if [ $rc -ne 0 ]; then 
         echo >"$HAPROXY_ERRORS" "Failed to query azure NIC"
         break
      fi

      # look up the private IP address
      ipaddr_private="$(cat "$nic_tmpfile" | jq ".ipConfigurations[0].privateIPAddress")"
      rc=$?

      if [ $rc -ne 0 ]; then 
         echo >"$HAPROXY_ERRORS" "Failed to query IP address object path for $nic_name"
         break
      fi

      if [ "$ipaddr_private" = "null" ]; then
         echo >"$HAPROXY_ERRORS" "WARN: NULL IP address for $nic_name"
         continue
      fi

      # strip quotes
      ipaddr_private="${ipaddr_private##\"}"
      ipaddr_private="${ipaddr_private%%\"}"

      echo -n "    server $vm_name $ipaddr_private\\\n"
   done

   # rm -f "$vm_tmpfile" "$nic_tmpfile" "$ipaddr_tmpfile"
   return $rc
}

# what's the original contents?
sha256_before=$(sha256sum "$HAPROXY_CFG" || echo "")
cfg_data="$(print_backends "$VM_TMPFILE" "$NIC_TMPFILE" "$IPADDR_TMPFILE")"
if [ $? -ne 0 ]; then 
   echo >"$HAPROXY_ERRORS" "WARN: failed to regenerate configuration"
   exit 1
fi

cat "$HAPROXY_CFG_IN" | \
   sed -e "s~@HAPROXY_BACKENDS@~$cfg_data~g;" > "$HAPROXY_CFG.tmp"

if [ $? -ne 0 ]; then 
   echo >"$HAPROXY_ERRORS" "WARN: failed to regenerate configuration"
   exit 1
fi

mv "$HAPROXY_CFG.tmp" "$HAPROXY_CFG"
sha256_after=$(sha256sum "$HAPROXY_CFG")

if [ "$sha256_before" != "$sha256_after" ]; then 
   # signal haproxy to reload
   systemctl reload haproxy
fi

exit 0
