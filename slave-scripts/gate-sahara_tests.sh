#!/bin/bash -xe

. $FUNCTION_PATH/functions-common.sh

plugin=$(split_job_name 3)
release=$(split_job_name 5)

case $release in
    liberty)
        ZUUL_BRANCH="stable/liberty"
        ;;
    mitaka)
        ZUUL_BRANCH="stable/mitaka"
        ;;
    *)
        feature=$release
esac

sahara_path="/tmp/sahara"
get_dependency "$sahara_path" "openstack/sahara" "$ZUUL_BRANCH"
cd "$sahara_path"

tox -e venv --notest
.tox/venv/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh "$sahara_path" "$WORKSPACE" "$feature"
