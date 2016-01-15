#!/bin/bash -xe

. $FUNCTION_PATH/functions-common.sh

sahara_path="/tmp/sahara"
get_dependency "$sahara_path" "openstack/sahara" "master"
cd "$sahara_path"

tox -e venv --notest
.tox/venv/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh "$sahara_path" "$WORKSPACE"
cd
rm -rf $sahara_path

get_dependency "$sahara_path" "openstack/sahara" "stable/kilo"
cd "$sahara_path"

tox -e venv --notest
.tox/venv/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh "$sahara_path" "$WORKSPACE"
