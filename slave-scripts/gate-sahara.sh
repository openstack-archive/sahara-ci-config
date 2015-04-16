#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH=${1:-$WORKSPACE}
sahara_conf_path=$SAHARA_PATH/etc/sahara/sahara.conf
# default (deprecated) config file for integration tests
tests_config_file="$SAHARA_PATH/sahara/tests/integration/configs/itest.conf"
tests_config_file_template="$sahara_templates_configs_path/itest.conf.sample"

job_type=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')
engine_type=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

# Image names
hdp_image=sahara_hdp_1_latest
hdp_two_image=sahara_hdp_2_latest
vanilla_image=ubuntu_vanilla_1_latest
vanilla_two_four_image=ubuntu_vanilla_2.4_latest
vanilla_two_six_image=ubuntu_vanilla_2.6_latest
spark_image=sahara_spark_latest
cdh_centos_image=centos_cdh_latest
cdh_ubuntu_image=ubuntu_cdh_latest

case $job_type in
    fake)
       plugin=fake
       fake_plugin_image=ubuntu-test-image
       tests_config_file="$SAHARA_PATH/etc/scenario/sahara-ci/fake.yaml"
       insert_scenario_value $tests_config_file fake_plugin_image
       insert_config_value $sahara_conf_path DEFAULT plugins fake
       ;;
    hdp_1)
       plugin=hdp1
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template HDP IMAGE_NAME $hdp_image
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-hdp.yaml"
          insert_scenario_value $tests_config_file hdp_image
       fi
       ;;
    hdp_2)
       DISTRIBUTE_MODE=True
       plugin=hdp2
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template HDP2 IMAGE_NAME $hdp_two_image
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-hdp-2.yaml"
          insert_scenario_value $tests_config_file hdp_two_image
       fi
       ;;
    vanilla_1)
       plugin=vanilla1
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template VANILLA IMAGE_NAME $vanilla_image
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-vanilla-1.2.1.yaml"
          insert_scenario_value $tests_config_file vanilla_image
       fi
       ;;
    vanilla_2.4)
       DISTRIBUTE_MODE=True
       plugin=vanilla2
       insert_config_value $tests_config_file_template VANILLA_TWO IMAGE_NAME $vanilla_two_four_image
       insert_config_value $tests_config_file_template VANILLA_TWO HADOOP_VERSION 2.4.1
       insert_config_value $tests_config_file_template VANILLA_TWO HADOOP_EXAMPLES_JAR_PATH "/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.4.1.jar"
       ;;
    vanilla_2.6)
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-vanilla-2.6.0.yaml"
       insert_scenario_value $tests_config_file vanilla_two_six_image
       ;;
    transient)
       plugin=transient
       concurrency=3
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template VANILLA_TWO SKIP_TRANSIENT_CLUSTER_TEST False
          insert_config_value $tests_config_file_template VANILLA_TWO ONLY_TRANSIENT_CLUSTER_TEST True
          insert_config_value $tests_config_file_template VANILLA_TWO IMAGE_NAME $vanilla_two_four_image
          insert_config_value $tests_config_file_template VANILLA_TWO HADOOP_VERSION 2.4.1
       else
          DISTRIBUTE_MODE=True
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-transient.yaml"
          insert_scenario_value $tests_config_file vanilla_two_six_image
       fi
       ;;
    cdh*)
       plugin=cdh
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       if [[ "$job_type" =~ centos ]]; then
          cdh_image=$cdh_centos_image
       else
          cdh_image=$cdh_ubuntu_image
       fi
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template CDH IMAGE_NAME $cdh_image
          insert_config_value $tests_config_file_template CDH SKIP_SCALING_TEST True
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-cdh.yaml"
          insert_scenario_value $tests_config_file cdh_image
       fi
       ;;
    spark)
       plugin=spark
       insert_config_value $sahara_conf_path DEFAULT plugins spark
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
           insert_config_value $tests_config_file_template SPARK IMAGE_NAME $spark_image
       else
           tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-spark.yaml"
           insert_scenario_value $tests_config_file spark_image
       fi
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
