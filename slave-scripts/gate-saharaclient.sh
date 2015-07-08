#!/bin/bash -xe

sahara_path="/tmp/sahara"
get_dependency "$sahara_path" "openstack/sahara"
cd "$sahara_path"

tox -e scenario --notest
.tox/scenario/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh "$sahara_path"
