#!/bin/bash -xe

. $FUNCTION_PATH/functions-common.sh

sahara_scenario_path="/tmp/sahara-scenario"
get_dependency "$sahara_scenario_path" "openstack/sahara-scenario" "master"
cd "$sahara_scenario_path"

tox -e venv --notest
.tox/venv/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh "$sahara_scenario_path"
