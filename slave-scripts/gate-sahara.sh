#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH=${1:-$WORKSPACE}
sahara_conf_path=$SAHARA_PATH/etc/sahara/sahara.conf
sahara_templates_path=$SAHARA_PATH/etc/scenario/sahara-ci

plugin=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')
os=$(echo $JOB_NAME | awk -F '-' '{ print $6 }')
engine_type=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')
${plugin}_image=${plugin}_${os}

case $plugin in
    hdp_1.3.2)
       tests_config_file="$sahara_templates_path/hdp-1.3.2.yaml"
       insert_scenario_value $tests_config_file hdp_1_3_2_image
       ;;
    hdp_2.0.6)
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/hdp-2.0.6.yaml"
       insert_scenario_value $tests_config_file hdp_2_0_6_image
       ;;
    vanilla_1.2.1)
       tests_config_file="$sahara_templates_path/vanilla-1.2.1.yaml"
       insert_scenario_value $tests_config_file vanilla_1_2_1_image
       ;;
    vanilla_2.6.0)
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/vanilla-2.6.0.yaml"
       insert_scenario_value $tests_config_file vanilla_2_6_0_image
       ;;
    transient)
       # transient is using image with latest vanilla version
       transient_image=vanilla_2.6.0-u14
       concurrency=3
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/transient.yaml"
       insert_scenario_value $tests_config_file transient_image
       ;;
    cdh_5.3.0)
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       tests_config_file="$sahara_templates_path/cdh-5.3.0.yaml"
       insert_scenario_value $tests_config_file cdh_5_3_0_image
       ;;
    spark_1.0.0)
       insert_config_value $sahara_conf_path DEFAULT plugins spark
       tests_config_file="$sahara_templates_path/spark-1.0.0.yaml"
       insert_scenario_value $tests_config_file spark_1_0_0_image
       ;;
    mapr_4.0.2.mrv2)
       insert_config_value $sahara_conf_path DEFAULT plugins mapr
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/mapr-4.0.2.mrv2.yaml"
       insert_scenario_value $tests_config_file mapr_4_0_2_mrv2_image
       ;;
esac

sudo pip install . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_path" "$engine_type"
write_tests_conf "$tests_config_file" "$cluster_name"
start_sahara "$sahara_conf_path" && run_tests "$tests_config_file" "$concurrency"
print_python_env
