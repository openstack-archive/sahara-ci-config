#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH=${1:-$WORKSPACE}
sahara_conf_file=$SAHARA_PATH/etc/sahara/sahara.conf
sahara_templates_path=$SAHARA_PATH/etc/scenario/sahara-ci

engine_type=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')
plugin=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')
os=$(echo $JOB_NAME | awk -F '-' '{ print $6 }')
image_name=${plugin}_${os}
mode="aio"
sahara_plugin=$(echo $plugin | awk -F '_' '{ print $1 } ')
template_vars_file=template_vars.ini

case $plugin in
    hdp_2.0.6)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/hdp-2.0.6.yaml.mako"
       template_image_prefix="hdp_two"
       ;;
    vanilla_2.6.0)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/vanilla-2.6.0.yaml.mako"
       template_image_prefix="vanilla_two_six"
       ;;
    transient)
       # transient is using image with latest vanilla version
       image_name=vanilla_2.6.0_u14
       sahara_plugin=vanilla
       concurrency=3
       mode=distribute
       scenario_conf_file="$sahara_templates_path/transient.yaml.mako"
       template_image_prefix="vanilla_two_six"
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
    mapr_4.0.2.mrv2)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/mapr-4.0.2.mrv2.yaml.mako"
       template_image_prefix="mapr_402mrv2"
       ;;
    fake)
       mode=distribute
       image_name=fake_image
       scenario_conf_file="$sahara_templates_path/fake.yaml.mako"
       template_image_prefix="fake_plugin"
       ;;
esac

sudo pip install . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_file" "$engine_type" "$sahara_plugin"
write_tests_conf "$template_vars_file" "$cluster_name" "$template_image_prefix" "$image_name"
start_sahara "$sahara_conf_file" "$mode" && run_tests "$template_vars_file" "$sahara_templates_path" "$scenario_conf_file" "$concurrency"
print_python_env
