#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source functions
. $FUNCTION_PATH/functions-common.sh
. $FUNCTION_PATH/functions-dib.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH="/tmp/sahara"
sahara_conf_path="$SAHARA_PATH/etc/sahara/sahara.conf"
sahara_templates_path=$SAHARA_PATH/etc/scenario/sahara-ci

engine=$(echo $JOB_NAME | awk -F '-' '{ print $3 }')
job_type="$1"
image_type=${2:-ubuntu}

# Image names
vanilla_image=$HOST-sahara-vanilla-${image_type}-${ZUUL_CHANGE}-hadoop_1
vanilla_two_six_image=$HOST-sahara-vanilla-${image_type}-${ZUUL_CHANGE}-hadoop_2.6
hdp_image=$HOST-sahara-hdp-centos-${ZUUL_CHANGE}-hadoop_1
hdp_two_image=$HOST-sahara-hdp-centos-${ZUUL_CHANGE}-hadoop_2
spark_image=$HOST-sahara-spark-ubuntu-${ZUUL_CHANGE}
cdh_image=$HOST-${image_type}-cdh-${ZUUL_CHANGE}

# Clone Sahara
git clone https://review.openstack.org/openstack/sahara $SAHARA_PATH

case $job_type in
    vanilla*)
       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username='ubuntu'
       fi

       hadoop_version=$(echo $job_type | awk -F '_' '{print $2}')
       case $hadoop_version in
           1)
              env ${image_type}_vanilla_hadoop_1_image_name=${vanilla_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 1
              check_error_code $? ${vanilla_image}.qcow2
              upload_image "vanilla-1" "${username}" ${vanilla_image}
              tests_config_file="$sahara_templates_path/vanilla-1.2.1.yaml"
              insert_scenario_value $tests_config_file vanilla_image
              ;;
           2.6)
              env ${image_type}_vanilla_hadoop_2_6_image_name=${vanilla_two_six_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2.6
              check_error_code $? ${vanilla_two_six_image}.qcow2
              upload_image "vanilla-2.6" "${username}" ${vanilla_two_six_image}
              DISTRIBUTE_MODE=True
              tests_config_file="$sahara_templates_path/vanilla-2.6.0.yaml"
              insert_scenario_value $tests_config_file vanilla_two_six_image
              ;;
       esac
    ;;

    spark)
       env ubuntu_spark_image_name=${spark_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p spark
       check_error_code $? ${spark_image}.qcow2
       upload_image "spark" "ubuntu" ${spark_image}
       tests_config_file="$sahara_templates_path/spark-1.0.0.yaml"
       insert_scenario_value $tests_config_file spark_image
       insert_config_value $sahara_conf_path DEFAULT plugins spark
    ;;

    hdp_1)
       env centos_hdp_hadoop_1_image_name=${hdp_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p hdp -v 1
       check_error_code $? ${hdp_image}.qcow2
       upload_image "hdp1" "root" ${hdp_image}
       tests_config_file="$sahara_templates_path/hdp-1.3.2.yaml"
       insert_scenario_value $tests_config_file hdp_image
    ;;

    hdp_2)
       env centos_hdp_hadoop_2_image_name=${hdp_two_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p hdp -v 2
       check_error_code $? ${hdp_two_image}.qcow2
       upload_image "hdp2" "root" ${hdp_two_image}
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/hdp-2.0.6.yaml"
       insert_scenario_value $tests_config_file hdp_two_image
    ;;

    cdh)
       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username='ubuntu'
       fi
       env cloudera_5_3_${image_type}_image_name=${cdh_image} SIM_REPO_PATH=$WORKSPACE bash -x diskimage-create/diskimage-create.sh -p cloudera -i $image_type -v 5.3
       check_error_code $? ${cdh_image}.qcow2
       upload_image "cdh" ${username} ${cdh_image}
       tests_config_file="$sahara_templates_path/cdh-5.3.0.yaml"
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       insert_scenario_value $tests_config_file cdh_image
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
start_sahara "$sahara_conf_path" && run_tests "$tests_config_file"
print_python_env
cleanup_image "$job_type" "$image_type"
