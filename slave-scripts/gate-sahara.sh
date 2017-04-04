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

# Clone Sahara Scenario tests
if [ "$ZUUL_PROJECT" != "openstack/sahara-tests" ]; then
    get_dependency "$SAHARA_TESTS_PATH" "openstack/sahara-tests" "master"
fi

plugin=$(echo $JOB_NAME | awk -F '-' '{ print $3 }')
os=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')
image_name=${plugin}_${os}
sahara_plugin=$(echo $plugin | awk -F '_' '{ print $1 } ')
scenario_conf_file=$(get_template_path $ZUUL_BRANCH $plugin $sahara_templates_path)

export plugin

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
    spark_1.6.0)
       if [ "$ZUUL_BRANCH" == "stable/mitaka" ]; then
           image_name="spark_1.6.0_u14_mitaka"
       fi
       ;;
esac

upper_constraints="https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt"

if [ "$ZUUL_BRANCH" != "master" ]; then
    upper_constraints+="?h=$ZUUL_BRANCH"
fi

pip_cmd="install -U -c $upper_constraints -r requirements.txt . --no-cache-dir"
pip_packages="pymysql"

case $(echo $JOB_NAME | awk -F '-' '{ print $NF }') in
    python3)
       sudo apt install python3-pip python3-dev -y
       sudo pip3 $pip_cmd
       sudo pip3 install $pip_packages
       ;;
    *)
       sudo pip $pip_cmd
       sudo pip install $pip_packages
       ;;
esac

enable_pypi
write_sahara_main_conf "$sahara_conf_file" "$sahara_plugin"
write_tests_conf "$cluster_name" "$image_name" "$scenario_conf_file"
start_sahara "$sahara_conf_file" "$mode" && run_tests "$scenario_conf_file"
print_python_env
