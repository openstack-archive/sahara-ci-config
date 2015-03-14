#!/bin/bash

sudo rm -rf /tmp/sahara
git clone https://git.openstack.org/openstack/sahara /tmp/sahara
CONFIG_PATH=sahara-ci-config/config/sahara

JOB_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')
cp -r /tmp/sahara-ci-config /tmp/sahara

cd /tmp/sahara
# prepare test dependencies
if [[ "$JOB_NAME" =~ scenario ]]; then
  tox -e scenario --notest
  .tox/scenario/bin/pip install $WORKSPACE
else
  tox -e integration --notest
  .tox/integration/bin/pip install $WORKSPACE
fi


bash -x /tmp/sahara-ci-config/slave-scripts/gate-sahara.sh /tmp/sahara
