#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source functions
. $FUNCTION_PATH/functions-common.sh
. $FUNCTION_PATH/functions-dib.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH="/tmp/sahara"
# default (deprecated) config file for integration tests
tests_config_file="$SAHARA_PATH/sahara/tests/integration/configs/itest.conf"
tests_config_file_template="$sahara_templates_configs_path/itest.conf.sample"
sahara_conf_path="$SAHARA_PATH/etc/sahara/sahara.conf"

engine=$(echo $JOB_NAME | awk -F '-' '{ print $3 }')
job_type="$1"
image_type=${2:-ubuntu}

# Image names
vanilla_image=$HOST-sahara-vanilla-${image_type}-${ZUUL_CHANGE}-hadoop_1
vanilla_two_four_image=$HOST-sahara-vanilla-${image_type}-${ZUUL_CHANGE}-hadoop_2.4
vanilla_two_six_image=$HOST-sahara-vanilla-${image_type}-${ZUUL_CHANGE}-hadoop_2.6
hdp_image=$HOST-sahara-hdp-centos-${ZUUL_CHANGE}-hadoop_1
hdp_two_image=$HOST-sahara-hdp-centos-${ZUUL_CHANGE}-hadoop_2
spark_image=$HOST-sahara-spark-ubuntu-${ZUUL_CHANGE}
cdh_image=$HOST-${image_type}-cdh-${ZUUL_CHANGE}

# Clone Sahara
git clone https://review.openstack.org/openstack/sahara $SAHARA_PATH

case $job_type in
    vanilla*)
       # Up local HTTPServer with Java source
       pushd /home/jenkins
       python -m SimpleHTTPServer 8000 > /dev/null &
       popd

       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username=${image_type}
       fi

       hadoop_version=$(echo $job_type | awk -F '_' '{print $2}')
       case $hadoop_version in
           1)
              sudo ${image_type}_vanilla_hadoop_1_image_name=${vanilla_image} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 1
              check_error_code $? ${vanilla_image}.qcow2
              upload_image "vanilla-1" "${username}" ${vanilla_image}
              if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
                 insert_config_value $tests_config_file_template VANILLA SKIP_CINDER_TEST True
                 insert_config_value $tests_config_file_template VANILLA SKIP_CLUSTER_CONFIG_TEST True
                 insert_config_value $tests_config_file_template VANILLA SKIP_SCALING_TEST True
                 insert_config_value $tests_config_file_template VANILLA IMAGE_NAME $vanilla_image
              else
                 tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-vanilla-1.2.1.yaml"
                 insert_scenario_value $tests_config_file vanilla_image
              fi
              plugin=vanilla1
              ;;
           2.4)
              sudo ${image_type}_vanilla_hadoop_2_4_image_name=${vanilla_two_four_image} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2.4
              check_error_code $? ${vanilla_two_four_image}.qcow2
              upload_image "vanilla-2.4" "${username}" ${vanilla_two_four_image}
              DISTRIBUTE_MODE=True
              insert_config_value $tests_config_file_template VANILLA_TWO SKIP_CINDER_TEST True
              insert_config_value $tests_config_file_template VANILLA_TWO SKIP_CLUSTER_CONFIG_TEST True
              insert_config_value $tests_config_file_template VANILLA_TWO SKIP_SCALING_TEST True
              insert_config_value $tests_config_file_template VANILLA_TWO IMAGE_NAME $vanilla_two_four_image
              plugin=vanilla2
              ;;
           2.6)
              sudo ${image_type}_vanilla_hadoop_2_6_image_name=${vanilla_two_six_image} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2.6
              check_error_code $? ${vanilla_two_six_image}.qcow2
              upload_image "vanilla-2.6" "${username}" ${vanilla_two_six_image}
              DISTRIBUTE_MODE=True
              tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-vanilla-2.6.0.yaml"
              insert_scenario_value $tests_config_file vanilla_two_six_image
              ;;
       esac
    ;;

    spark)
       # Up local HTTPServer with Java source
       pushd /home/jenkins
       python -m SimpleHTTPServer 8000 > /dev/null &
       popd

       sudo ubuntu_spark_image_name=${spark_image} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p "spark"
       check_error_code $? ${spark_image}.qcow2
       upload_image "spark" "ubuntu" ${spark_image}
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template SPARK SKIP_CINDER_TEST True
          insert_config_value $tests_config_file_template SPARK SKIP_CLUSTER_CONFIG_TEST True
          insert_config_value $tests_config_file_template SPARK SKIP_SCALING_TEST True
          insert_config_value $tests_config_file_template SPARK IMAGE_NAME $spark_image
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-spark.yaml"
          insert_scenario_value $tests_config_file spark_image
       fi
       plugin=spark
       insert_config_value $sahara_conf_path DEFAULT plugins spark
    ;;

    hdp_1)
       sudo centos_hdp_hadoop_1_image_name=${hdp_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p hdp -v 1
       check_error_code $? ${hdp_image}.qcow2
       upload_image "hdp1" "root" ${hdp_image}
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template HDP SKIP_CINDER_TEST True
          insert_config_value $tests_config_file_template HDP SKIP_CLUSTER_CONFIG_TEST True
          insert_config_value $tests_config_file_template HDP SKIP_SCALING_TEST True
          insert_config_value $tests_config_file_template HDP IMAGE_NAME $hdp_image
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-hdp.yaml"
          insert_scenario_value $tests_config_file hdp_image
       fi
       plugin=hdp1
    ;;

    hdp_2)
       sudo centos_hdp_hadoop_2_image_name=${hdp_two_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p hdp -v 2
       check_error_code $? ${hdp_two_image}.qcow2
       upload_image "hdp2" "root" ${hdp_two_image}
       DISTRIBUTE_MODE=True
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template HDP2 SKIP_CINDER_TEST True
          insert_config_value $tests_config_file_template HDP2 SKIP_CLUSTER_CONFIG_TEST True
          insert_config_value $tests_config_file_template HDP2 SKIP_SCALING_TEST True
          insert_config_value $tests_config_file_template HDP2 IMAGE_NAME $hdp_two_image
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-hdp-2.yaml"
          insert_scenario_value $tests_config_file hdp_two_image
       fi
       plugin=hdp2
    ;;

    cdh)
       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username='ubuntu'
       fi
       sudo cloudera_5_3_${image_type}_image_name=${cdh_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p cloudera -i $image_type -v 5.3
       check_error_code $? ${cdh_image}.qcow2
       upload_image "cdh" ${username} ${cdh_image}
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       if [ "$ZUUL_BRANCH" == "stable/juno" ]; then
          insert_config_value $tests_config_file_template CDH SKIP_CINDER_TEST True
          insert_config_value $tests_config_file_template CDH SKIP_CLUSTER_CONFIG_TEST True
          insert_config_value $tests_config_file_template CDH SKIP_SCALING_TEST True
          insert_config_value $tests_config_file_template CDH IMAGE_NAME $cdh_image
       else
          tests_config_file="$sahara_templates_configs_path/scenario/sahara-scenario-cdh.yaml"
          insert_scenario_value $tests_config_file cdh_image
       fi
       plugin=cdh
    ;;
esac

cd $SAHARA_PATH
if [ "$ZUUL_BRANCH" != "master" ]; then
   git checkout "$ZUUL_BRANCH"
   sudo pip install -U -r requirements.txt
fi
sudo pip install .
enable_pypi
write_sahara_main_conf "$sahara_conf_path" "$engine"
write_tests_conf "$tests_config_file" "$cluster_name"
start_sahara "$sahara_conf_path" && run_tests "$tests_config_file" "$plugin"
print_python_env
cleanup_image "$job_type" "$image_type"
