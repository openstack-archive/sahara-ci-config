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

job_type=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')
engine_type=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

# Image names
hdp_image=sahara_hdp_1_latest
hdp_two_image=sahara_hdp_2_latest
vanilla_image=ubuntu_vanilla_1_latest
vanilla_two_six_image=ubuntu_vanilla_2.6_latest
spark_image=sahara_spark_latest
cdh_5.3.0_centos_image=centos_cdh_latest
cdh_5.3.0_ubuntu_image=ubuntu_cdh_latest
cdh_5.4.0_image=ubuntu_cdh_5.4.0_latest
mapr_402mrv2_image=ubuntu_mapr_latest

case $job_type in
    hdp_1)
       tests_config_file="$sahara_templates_path/hdp-1.3.2.yaml"
       insert_scenario_value $tests_config_file hdp_image
       ;;
    hdp_2)
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/hdp-2.0.6.yaml"
       insert_scenario_value $tests_config_file hdp_two_image
       ;;
    vanilla_1)
       tests_config_file="$sahara_templates_path/vanilla-1.2.1.yaml"
       insert_scenario_value $tests_config_file vanilla_image
       ;;
    vanilla_2.6)
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/vanilla-2.6.0.yaml"
       insert_scenario_value $tests_config_file vanilla_two_six_image
       ;;
    transient)
       concurrency=3
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/transient.yaml"
       insert_scenario_value $tests_config_file vanilla_two_six_image
       ;;
    cdh_5.3*)
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       if [[ "$job_type" =~ centos ]]; then
          cdh_image=$cdh_5.3.0_centos_image
       else
          cdh_image=$cdh_5.3.0_ubuntu_image
       fi
       tests_config_file="$sahara_templates_path/cdh-5.3.0.yaml"
       insert_scenario_value $tests_config_file cdh_image
       ;;
    cdh_5.4.0)
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       tests_config_file="$sahara_templates_path/cdh-5.4.0.yaml"
       insert_scenario_value $tests_config_file cdh_5.4.0_image
    ;;
    spark)
       insert_config_value $sahara_conf_path DEFAULT plugins spark
       tests_config_file="$sahara_templates_path/spark-1.0.0.yaml"
       insert_scenario_value $tests_config_file spark_image
       ;;
    mapr)
       insert_config_value $sahara_conf_path DEFAULT plugins mapr
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/mapr-4.0.2.mrv2.yaml"
       insert_scenario_value $tests_config_file mapr_402mrv2_image
       ;;
esac

sudo pip install . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_path" "$engine_type"
write_tests_conf "$tests_config_file" "$cluster_name"
start_sahara "$sahara_conf_path" && run_tests "$tests_config_file" "$concurrency"
print_python_env
