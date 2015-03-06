#!/bin/bash -xe

sudo pip install .

git clone https://git.openstack.org/openstack/sahara /tmp/sahara
cd /tmp/sahara
bash -x $WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh /tmp/sahara
