#!/bin/bash

sudo rm -rf /tmp/sahara
git clone https://git.openstack.org/openstack/sahara /tmp/sahara
cd /tmp/sahara
# prepare test dependencies
tox -e integration --notest

# change sahara-client
.tox/integration/bin/pip install $WORKSPACE

bash -x /tmp/sahara-ci-config/slave-scripts/gate-sahara.sh /tmp/sahara
