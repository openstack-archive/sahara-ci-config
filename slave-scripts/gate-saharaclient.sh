#!/bin/bash

sudo rm -rf /tmp/sahara
git clone https://git.openstack.org/openstack/sahara /tmp/sahara
cd /tmp/sahara
# prepare test dependencies
tox -e integration --notest

# change sahara-client
.tox/integration/bin/pip install $WORKSPACE

JOB_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $3 }')
if [ "$JOB_TYPE" != "tempest" ]; then
   bash -x /tmp/sahara-ci-config/slave-scripts/gate-sahara.sh /tmp/sahara
else
   bash -x /tmp/sahara-ci-config/slave-scripts/gate-saharaclient-tempest.sh /tmp/sahara
fi
