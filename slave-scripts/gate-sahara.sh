#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH=${1:-$WORKSPACE}
SAHARA_TESTS_PATH="/tmp/sahara-scenario"
sahara_conf_file=$SAHARA_PATH/etc/sahara/sahara.conf
sahara_templates_path=$SAHARA_TESTS_PATH/etc/scenario/sahara-ci

# Clone Sahara Scenario tests
get_dependency "$SAHARA_TESTS_PATH" "openstack/sahara-scenario"

engine_type=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')
plugin=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')
os=$(echo $JOB_NAME | awk -F '-' '{ print $6 }')
image_name=${plugin}_${os}
mode="aio"
sahara_plugin=$(echo $plugin | awk -F '_' '{ print $1 } ')

case $plugin in
    hdp_2.0.6)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/hdp-2.0.6.yaml.mako"
       template_image_prefix="hdp_two"
       ;;
    ambari_2.3)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/ambari-2.3.yaml.mako"
       template_image_prefix="ambari_2_1"
       image_name="ambari_2.1_c6.6"
       ;;
    vanilla_2.6.0)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/vanilla-2.6.0.yaml.mako"
       template_image_prefix="vanilla_two_six"
       ;;
    vanilla_2.7.1)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/vanilla-2.7.1.yaml.mako"
       template_image_prefix="vanilla_two_seven_one"
    ;;
    transient)
       # transient is using image with latest vanilla version
       if [ "$ZUUL_BRANCH" == "stable/kilo" ]; then
        image_name=vanilla_2.6.0_u14
        template_image_prefix="vanilla_two_six"
       else
        image_name=vanilla_2.7.1_u14
        template_image_prefix="vanilla_two_seven_one"
       fi
       sahara_plugin=vanilla
       concurrency=3
       mode=distribute
       scenario_conf_file="$sahara_templates_path/transient.yaml.mako"
       ;;
    cdh_5.3.0)
       scenario_conf_file="$sahara_templates_path/cdh-5.3.0.yaml.mako"
       template_image_prefix="cdh"
       ;;
    cdh_5.4.0)
       scenario_conf_file="$sahara_templates_path/cdh-5.4.0.yaml.mako"
       template_image_prefix="cdh_5_4_0"
       ;;
    spark_1.0.0)
       scenario_conf_file="$sahara_templates_path/spark-1.0.0.yaml.mako"
       template_image_prefix="spark"
       ;;
    spark_1.3.1)
       scenario_conf_file="$sahara_templates_path/spark-1.3.1.yaml.mako"
       template_image_prefix="spark_1_3"
       ;;
    mapr_5.0.0.mrv2)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/mapr-5.0.0.mrv2.yaml.mako"
       template_image_prefix="mapr_500mrv2"
       ;;
    fake)
       mode=distribute
       image_name=fake_image
       scenario_conf_file="$sahara_templates_path/fake.yaml.mako"
       template_image_prefix="fake_plugin"
       ;;
esac

sudo pip install -r requirements.txt . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_file" "$engine_type" "$sahara_plugin"
write_tests_conf "$cluster_name" "$template_image_prefix" "$image_name" "$scenario_conf_file" # support kilo
start_sahara "$sahara_conf_file" "$mode" && run_tests "$scenario_conf_file" "$concurrency"
print_python_env
