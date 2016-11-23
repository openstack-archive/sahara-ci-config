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
mode="distribute"
concurrency=1
sahara_plugin=$(echo $plugin | awk -F '_' '{ print $1 } ')
scenario_conf_file=$(get_template_path $ZUUL_BRANCH $plugin $sahara_templates_path)

case $plugin in
    ambari_2.3)
       template_image_prefix="ambari_2_2"
       image_name="ambari_2.2_c7"
       ;;
    ambari_2.4)
       template_image_prefix="ambari_2_2"
       image_name="ambari_2.2_c7"
       if [ $os == "u14" ]; then
           image_name="ambari_2.2_u14"
       fi
       ;;
    vanilla_2.7.1)
       # the only job to test aio approach
       mode="aio"
       template_image_prefix="vanilla_two_seven_one"
    ;;
    cdh_5.4.0)
       template_image_prefix="cdh_5_4_0"
       ;;
    cdh_5.5.0)
       template_image_prefix="cdh_5_5_0"
       ;;
    cdh_5.7.0)
       template_image_prefix="cdh_5_7_0"
       ;;
    spark_1.3.1)
       template_image_prefix="spark_1_3"
       ;;
    spark_1.6.0)
       template_image_prefix="spark_1_6"
       ;;
    mapr_5.1.0.mrv2)
       template_image_prefix="mapr_510mrv2"
       ;;
    mapr_5.2.0.mrv2)
       template_image_prefix="mapr_520mrv2"
       ;;
    storm_1.0.1)
       template_image_prefix="storm_1_0"
       ;;
esac

sudo pip install -r requirements.txt . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_file" "$sahara_plugin"
write_tests_conf "$cluster_name" "$template_image_prefix" "$image_name" "$scenario_conf_file"
start_sahara "$sahara_conf_file" "$mode" && run_tests "$scenario_conf_file" "$concurrency"
print_python_env
