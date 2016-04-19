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
    *)
        case $plugin in
            vanilla_2.6.0)
                ZUUL_BRANCH="stable/kilo"
                ;;
            cdh_5.3.0)
                ZUUL_BRANCH="stable/kilo"
                ;;
            spark_1.0.0)
                ZUUL_BRANCH="stable/kilo"
                ;;
        esac
esac

sahara_path="/tmp/sahara"
get_dependency "$sahara_path" "openstack/sahara" "$ZUUL_BRANCH"
cd "$sahara_path"

tox -e venv --notest
.tox/venv/bin/pip install $WORKSPACE

$WORKSPACE/sahara-ci-config/slave-scripts/gate-sahara.sh "$sahara_path" "$WORKSPACE"
