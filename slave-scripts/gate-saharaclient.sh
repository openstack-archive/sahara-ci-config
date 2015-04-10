#!/bin/bash -xe

git clone https://git.openstack.org/openstack/sahara /tmp/sahara
cd /tmp/sahara

if [ "$ZUUL_BRANCH" == "master" -o "$ZUUL_BRANCH" == "proposed/kilo" ]; then
  tox -e scenario --notest
  .tox/scenario/bin/pip install $WORKSPACE
else
  git checkout "$ZUUL_BRANCH"
  sudo pip install -U -r requirements.txt
  tox -e integration --notest
  .tox/integration/bin/pip install $WORKSPACE
fi

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh /tmp/sahara
