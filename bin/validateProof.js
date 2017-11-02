#!/usr/bin/node

var b = require('blockstack');
var assert = require('assert');

var args = process.argv.slice(2);

var addr = args[0];
assert(addr);

var whichProof = null;
if (args.length > 1) {
    whichProof = args[1]
}

var url = `https://gaia.blockstack.org/hub/${addr}/0/profile.json`
console.log(`url: ${url}`);

fetch(url)
   .then((r) => {return r.json();}, (e) => {console.log(e.stack);})
   .then((j) => {return j[0].decodedToken.payload.claim}, (error) => {console.log(error.stack);})
   .then((p) => {
      if (whichProof) {
         var idx = 0;
         var found = false;
         for (idx = 0; idx < p.account.length; idx++) {
            if (p.account[idx].service === whichProof) {
               found = true;
               break;
            }
         }
         if (!found) {
            throw new Error("No service: " + whichProof)
         }

         var proof = {
            'identifier': p.account[idx].identifier,
            'proof_url': p.account[idx].proofUrl,
            'service': p.account[idx].service,
            'valid': false,
         };
         return b.profileServices[whichProof].validateProof(proof, addr).then((a) => {console.log(a)}, (e) => {console.log("error: " + e.stack);});
      }
      else {
         for (var i = 0; i < p.account.length; i++) {
            console.log("Validate " + p.account[i].service + " (" + p.account[i].proofUrl + ")");
         }

         return b.validateProofs(p, addr).then(console.log, (e) => {console.log("validation error: " + e.stack);})
      }
   },
   (error) => {console.log(error.stack);})

