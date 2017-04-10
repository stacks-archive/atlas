#!/bin/sh

certbot --standalone --tls-sni-01-port 63443 -d utxo.blockstack.org
