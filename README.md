blockstack-resolver
=======

[![CircleCI](https://img.shields.io/circleci/project/blockstack/blockstack-resolver/master.svg)](https://circleci.com/gh/blockstack/blockstack-resolver)
[![Slack](http://slack.blockstack.org/badge.svg)](http://slack.blockstack.org/)

### Overview

The Blockstack resolver is a highly scalable server for resolving [Blockstack names](https://blockstack.org/docs/what-is-blockstack) to profile data.

The Blockstack resolver is primarily meant for scaling read-only calls to the underlying blockchain. In order to achieve high throughput, the resolver loads the entire namespace into `memcached` and then keeps the local copy consistent with the blockchain. Read-only calls don't hit the blockchain daemon and their scalability is completely decoupled from the scalability properties of the underlying blockchain software.

The resolver is blockchain-agnostic, but is currently configured to use the Bitcoin blockchain. An earlier release (version 0.2) of this resolver used the Namecoin blockchain.

### Contributing

This is open source software and we welcome all contributions.

Some things to note:

* The [develop](https://github.com/blockstack/resolver/tree/develop) branch is the most active one and uses Bitcoin. Please use that branch for submitting pull requests.
* An [earlier version](https://github.com/blockstack/resolver/releases/tag/v0.2) of this package had support for Namecoin. We no longer support Namecoin.

### API Calls

Example API call:

```bash
$ curl http://localhost:5000/v2/username/fredwilson
```

### Quick Deployment

```bash
$ pip install -r requirements.txt
$ ./runserver
```

For deploying the resolver in production, see [this page](https://github.com/blockstack/resolver/tree/master/apache).

### License

GPL v3. See LICENSE.

Copyright: (c) 2016 by Blockstack.org
