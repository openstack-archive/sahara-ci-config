#!/bin/bash

git clone https://github.com/openstack/sahara /tmp/sahara
cd /tmp/sahara
# prepare test dependencies
tox -e integration --notest

# change sahara-client
.tox/integration/bin/pip install $WORKSPACE

bash /tmp/sahara-ci-config/scripts/gate-savanna-integration-new.sh /tmp/sahara
