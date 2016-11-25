#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH=${1:-$WORKSPACE}
SAHARA_TESTS_PATH=${2:-"/tmp/sahara-tests"}
sahara_conf_file=$SAHARA_PATH/etc/sahara/sahara.conf
sahara_templates_path=$SAHARA_TESTS_PATH/sahara_tests/scenario/defaults
tests_etc=$sahara_templates_path
feature=${3}

# Clone Sahara Scenario tests
if [ "$ZUUL_PROJECT" != "openstack/sahara-tests" ]; then
    get_dependency "$SAHARA_TESTS_PATH" "openstack/sahara-tests" "master"
    feature=split_job_name 5
fi

plugin=$(split_job_name 3)
os=$(split_job_name 4)
image_name=${plugin}_${os}
sahara_plugin=$(echo $plugin | awk -F '_' '{ print $1 } ')
scenario_conf_file=$(get_template_path $ZUUL_BRANCH $plugin $sahara_templates_path)
image_variable_name=$(get_image_variable_name $scenario_conf_file)

case $plugin in
    ambari_2.3)
       image_name="ambari_2.2_c7"
       ;;
    ambari_2.4)
       image_name="ambari_2.2_c7"
       if [ $os == "u14" ]; then
           image_name="ambari_2.2_u14"
       fi
       ;;
    vanilla_2.7.1)
       # the only job to test aio approach
       mode="aio"
       ;;
esac

case $feature in
    python3)
       alias python=python3
       ;;
esac

sudo pip install -r requirements.txt . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_file" "$sahara_plugin"
write_tests_conf "$cluster_name" "$image_variable_name" "$image_name" "$scenario_conf_file"
start_sahara "$sahara_conf_file" "$mode" && run_tests "$scenario_conf_file"
print_python_env
