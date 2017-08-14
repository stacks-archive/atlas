# The Atlas peer network

Note: If you're looking for the resolver repo it was merged with [Blockstack Core](https://github.com/blockstack/blockstack-core).

This is the repo for the Atlas peer network used by Blockstack and some associated monitoring tools.

- [Atlas](/atlas)
- [bitcoind](/bitcoind)
- [haproxy](/haproxy)
- [Uptime Monitoring](/monitoring)

## Atlas Networks

All Atlas nodes maintain a 100% state replica, and they organize into an unstructured
overlay network. The unstructured approach is easier to implement, has no overhead
for maintaining routing structure and is resilient against targeted node attacks.
When a new Atlas node boots up, it first gets the index of all data keys and hashes of
values stored in the blockchain. After getting the index, Atlas nodes talk to their peers
to fetch key/value pairs they dont have. The Atlas network implements a K-regular
random graph.