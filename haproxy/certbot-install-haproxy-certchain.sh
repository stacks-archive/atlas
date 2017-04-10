#!/bin/sh

# see https://www.digitalocean.com/community/tutorials/how-to-secure-haproxy-with-let-s-encrypt-on-ubuntu-14-04

# run with 'sudo -E'
cat /etc/letsencrypt/live/utxo.blockstack.org/fullchain.pem /etc/letsencrypt/live/utxo.blockstack.org/privkey.pem > /etc/ssl/private/utxo.blockstack.org.pem

