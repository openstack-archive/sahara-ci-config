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
${plugin//./_}_image=${plugin}_${os}_latest
mode="aio"
sahara_plugin=$(echo $plugin | awk -F '_' '{ print $1 } ')

case $plugin in
    hdp_1.3.2)
       scenario_conf_file="$sahara_templates_path/hdp-1.3.2.yaml"
       insert_scenario_value $scenario_conf_file hdp_1_3_2_image
       ;;
    hdp_2.0.6)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/hdp-2.0.6.yaml"
       insert_scenario_value $scenario_conf_file hdp_2_0_6_image
       ;;
    vanilla_1.2.1)
       scenario_conf_file="$sahara_templates_path/vanilla-1.2.1.yaml"
       insert_scenario_value $scenario_conf_file vanilla_1_2_1_image
       ;;
    vanilla_2.6.0)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/vanilla-2.6.0.yaml"
       insert_scenario_value $scenario_conf_file vanilla_2_6_0_image
       ;;
    transient)
       # transient is using image with latest vanilla version
       transient_image=vanilla_2.6.0_u14
       concurrency=3
       mode=distribute
       scenario_conf_file="$sahara_templates_path/transient.yaml"
       insert_scenario_value $scenario_conf_file transient_image
       ;;
    cdh_5.3.0)
       scenario_conf_file="$sahara_templates_path/cdh-5.3.0.yaml"
       insert_scenario_value $scenario_conf_file cdh_5_3_0_image
       ;;
    cdh_5.4.0)
       scenario_conf_file="$sahara_templates_path/cdh-5.4.0.yaml"
       insert_scenario_value $scenario_conf_file cdh_5_4_0_image
    ;;
    spark_1.0.0)
       scenario_conf_file="$sahara_templates_path/spark-1.0.0.yaml"
       insert_scenario_value $scenario_conf_file spark_1_0_0_image
       ;;
    mapr_4.0.2.mrv2)
       mode=distribute
       scenario_conf_file="$sahara_templates_path/mapr-4.0.2.mrv2.yaml"
       insert_scenario_value $scenario_conf_file mapr_4_0_2_mrv2_image
       ;;
esac

sudo pip install . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_file" "$engine_type" "$sahara_plugin"
write_tests_conf "$scenario_conf_file" "$cluster_name"
start_sahara "$sahara_conf_file" "$mode" && run_tests "$scenario_conf_file" "$concurrency"
print_python_env
