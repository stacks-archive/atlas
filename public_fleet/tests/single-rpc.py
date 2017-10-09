#!/usr/bin/python2
import sys
import requests
import simplejson
import traceback

headers = {'content-type': 'application/json'}

bitcoind_opts = {
    'bitcoind_user': 'blockstack',
    'bitcoind_passwd': 'blockstacksystem',
    'bitcoind_server': 'bitcoin.blockstack.com',
    'bitcoind_port': 81
}

txids = [
    'c698ac4b4a61c90b2c93dababde867dea359f971e2efcf415c37c9a4d9c4f312',
    '7cfdfcf0c0abac9641ed5e253e7ba2b3ddabbc0b15302a4fc138519dd028d3ea',
    '1510e1582f48c7ea1c57156e6ac5ae0d2c0960cfb4d17db0860e140f6900beed',
    'e2029990fa75e9fc642f149dad196ac6b64b9c4a6db254f23a580b7508fc34d7',
]

reqs = [
    {'method': 'getrawtransaction', 'params': [txid, 0], 'jsonrpc': '2.0', 'id': i}
    for i, txid in enumerate(txids)
]

proto = 'http'
server_url = "%s://%s:%s@%s:%s" % (proto, bitcoind_opts['bitcoind_user'], bitcoind_opts['bitcoind_passwd'], bitcoind_opts['bitcoind_server'], bitcoind_opts['bitcoind_port'])

print 'POST {}'.format(server_url)
print simplejson.dumps(reqs, indent=4, sort_keys=True)

resps = []

for req in reqs:
    try:
        resp = requests.post( server_url, headers=headers, data=simplejson.dumps(req), verify=False )
    except Exception, e:
        traceback.print_exc()
        sys.exit(1)

    # get responses
    try:
        resp_json = resp.json()
    except Exception, e:
        traceback.print_exc()
        sys.exit(1)

    resps.append(resp_json)

print simplejson.dumps(resps, indent=4, sort_keys=True)
