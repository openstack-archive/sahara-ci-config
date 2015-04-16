#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH=${1:-$WORKSPACE}
sahara_conf_path=$SAHARA_PATH/etc/sahara/sahara.conf

job_type=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')
engine_type=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

# Image names
hdp_image=sahara_hdp_1_latest
hdp_two_image=sahara_hdp_2_latest
vanilla_image=ubuntu_vanilla_1_latest
vanilla_two_six_image=ubuntu_vanilla_2.6_latest
spark_image=sahara_spark_latest
cdh_centos_image=centos_cdh_latest
cdh_ubuntu_image=ubuntu_cdh_latest

case $job_type in
    hdp_1)
       plugin=hdp1
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-hdp.yaml"
       insert_scenario_value $tests_config_file hdp_image
       ;;
    hdp_2)
       DISTRIBUTE_MODE=True
       plugin=hdp2
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-hdp-2.yaml"
       insert_scenario_value $tests_config_file hdp_two_image
       ;;
    vanilla_1)
       plugin=vanilla1
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-vanilla-1.2.1.yaml"
       insert_scenario_value $tests_config_file vanilla_image
       ;;
    vanilla_2.6)
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-vanilla-2.6.0.yaml"
       insert_scenario_value $tests_config_file vanilla_two_six_image
       ;;
    transient)
       plugin=transient
       concurrency=3
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-transient.yaml"
       insert_scenario_value $tests_config_file vanilla_two_six_image
       ;;
    cdh*)
       plugin=cdh
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       if [[ "$job_type" =~ centos ]]; then
          cdh_image=$cdh_centos_image
       else
          cdh_image=$cdh_ubuntu_image
       fi
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-cdh.yaml"
       insert_scenario_value $tests_config_file cdh_image
       ;;
    spark)
       plugin=spark
       insert_config_value $sahara_conf_path DEFAULT plugins spark
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-spark.yaml"
       insert_scenario_value $tests_config_file spark_image
       ;;
esac
echo "$plugin detected"

[ "$ZUUL_BRANCH" != "master" ] && sudo pip install -U -r requirements.txt
sudo pip install .
enable_pypi
write_sahara_main_conf "$sahara_conf_path" "$engine_type"
write_tests_conf "$tests_config_file" "$cluster_name"
start_sahara "$sahara_conf_path" && run_tests "$tests_config_file" "$plugin" "$concurrency"
print_python_env
