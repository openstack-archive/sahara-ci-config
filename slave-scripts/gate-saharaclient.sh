#!/bin/bash -xe

sudo pip install .

git clone https://git.openstack.org/openstack/sahara /tmp/sahara
cd /tmp/sahara
if [ "$ZUUL_BRANCH" != "master" ]; then
   git checkout "$ZUUL_BRANCH"
   sudo pip install -U -r requirements.txt
fi
bash -x $WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh /tmp/sahara
