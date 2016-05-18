#!/bin/bash -xe

. $FUNCTION_PATH/functions-common.sh

plugin=$(echo $JOB_NAME | awk -F '-' '{ print $3 }')
release=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')

case $release in
    liberty)
        ZUUL_BRANCH="stable/liberty"
        ;;
    mitaka)
        ZUUL_BRANCH="stable/mitaka"
        ;;
esac

sahara_path="/tmp/sahara"
get_dependency "$sahara_path" "openstack/sahara" "$ZUUL_BRANCH"
cd "$sahara_path"

tox -e venv --notest
.tox/venv/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh "$sahara_path" "$WORKSPACE"
