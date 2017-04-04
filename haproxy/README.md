Loadbalancer Scripts
====================

These scripts are meant to help set up load balancers on EC2 and Azure for a set
of back-end Blockstack infrastructure, like Bitcoin nodes and Blockstack Indexer
nodes.

Some assembly required and batteries not included.  You will need to tailor them
to your own needs.

### Config files

* `haproxy.cfg.in`:  This is a template file for HAProxy.  The string
`@HAPROXY_BACKENDS` will be replaced with a list of server backends by each of
these contained scripts.  The one here is meant for enabling HAProxy to balance
both p2p and JSONRPC load across a set of `bitcoind` daemons.  Put it in your
`/etc/haproxy` directory.

* `/etc/crontab`:  You will want to add a line like this to your crontab:
```
*/5 *   * * *   root    cd / && /etc/haproxy/haproxy-reload.sh
```

### HAProxy Config-generation Scripts

These are a family of very similar scripts that, when invoked, will set up
HAProxy to balance load across a set of VMs.  The scripts fill in
`haproxy.cfg.in` by querying the IaaS for the IP addresses
of VMs with a particular tag.  They only reload HAProxy if the config file
actually changes.

Once installed, the workflow here is to spin up one or more
VMs that run your backend process (like `bitcoind` or `bitcored`), give them an
appropriate tag, and then run this script to update HAProxy.  It is recommended
that the script simply run as part of a frequent cron job.

* `haproxy-reload-ec2.sh`:  This is a script for periodically re-generating
`/etc/haproxy/haproxy.cfg` from `/etc/haproxy/haproxy.cfg.in` and the `aws` CLI
tool.  To use it, you will need to have installed and set up your `aws`
credentials on the load-balancer node.  The script itself finds any VMs tagged
with `haproxy=1` and puts their IP addresses into `haproxy.cfg.in`.

* `haproxy-reload-azure.sh`:  This is a script for doing the same as
`haproxy-reload-ec2.sh`, but with the `azure` tool.  To use it, you will
need to have installed and set up `jq` and `azure-cli` on your load balancer,
and you will need to have signed into your subscription.  You will want to edit
this script and change `SUBSCRIPTION=` and `RESOURCE_GROUP=` to the appropriate
fields.  In addition, you will want to change `LOADBALANCE_TAG=` to whatever tag
you want to use to identify the VMs this script queries.


