#!/bin/bash -xe

git clone https://git.openstack.org/openstack/sahara /tmp/sahara -b $ZUUL_BRANCH
cd /tmp/sahara

tox -e scenario --notest
.tox/scenario/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh /tmp/sahara
