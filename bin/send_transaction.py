#!/usr/bin/env python2

import blockstack_client
import virtualchain
import keylib
import sys
import traceback
import pybitcoin
import json

amount = None

try:
    privkey = sys.argv[1]
    recipient_addr = sys.argv[2]

    if len(sys.argv) > 3:
        amount = int(sys.argv[3])

except Exception as e:
    traceback.print_exc()
    print >> sys.stderr, "Usage: {} privkey recipient_addr [amount]".format(sys.argv[0])
    sys.exit(1)

pubkey = keylib.ECPrivateKey(privkey, compressed=False).public_key().to_hex()
payment_addr = keylib.ECPublicKey(pubkey).address()

utxos = blockstack_client.get_utxos(payment_addr)
if len(utxos) == 0:
    print >> sys.stderr, "No UTXOS for {} ({})".format(payment_addr, pubkey)
    sys.exit(1)


def mktx(satoshis, fee):

    outputs = None
    if satoshis is None:
        # send all
        satoshis = sum([u['value'] for u in utxos])

        print 'WARN: sending all of {} ({}) to {}'.format(payment_addr, satoshis, recipient_addr)

        outputs = [
            {'script': virtualchain.make_payment_script(payment_addr),
             'value': virtualchain.calculate_change_amount(utxos, 0, fee)},
        ]
        
    else:
        outputs = [
            {"script": virtualchain.make_payment_script(payment_addr),
             "value": satoshis},
        
            {"script": virtualchain.make_payment_script(recipient_addr),
             "value": virtualchain.calculate_change_amount(utxos, satoshis, fee)},
        ]

    txobj = {
        'ins': utxos,
        'outs': outputs,
        'locktime': 0,
        'version': 1
    }

    # log.debug("serialize tx: {}".format(json.dumps(txobj, indent=4, sort_keys=True)))
    txstr = virtualchain.btc_tx_serialize(txobj)
    signed_txstr = virtualchain.tx_sign_all_unsigned_inputs(privkey, utxos, txstr)
    return signed_txstr

signed_tx = mktx(amount, 0)
tx_fee = virtualchain.get_tx_fee(signed_tx, config_path=blockstack_client.CONFIG_PATH)
assert tx_fee

signed_tx = mktx(amount, tx_fee)

print 'tx_fee: {}'.format(tx_fee)
print "tx:"
print signed_tx
print ""
print json.dumps( virtualchain.btc_tx_deserialize(signed_tx), indent=4, sort_keys=True )

send = raw_input("Send? (Y/n): ")
if send != 'Y':
   sys.exit(0)

else:
   res = blockstack_client.broadcast_tx(signed_tx)
   print json.dumps(res, indent=4, sort_keys=True)

