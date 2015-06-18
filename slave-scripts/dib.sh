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
vanilla_two_six_image=$HOST-sahara-vanilla-${image_type}-${ZUUL_CHANGE}-hadoop_2.6
hdp_two_image=$HOST-sahara-hdp-centos-${ZUUL_CHANGE}-hadoop_2
spark_image=$HOST-sahara-spark-ubuntu-${ZUUL_CHANGE}
cdh_image=$HOST-${image_type}-cdh-${ZUUL_CHANGE}
cdh_5_4_0_image=$HOST-${image_type}-cdh_5.4.0-${ZUUL_CHANGE}
mapr_402mrv2_image=$HOST-${image_type}-mapr-${ZUUL_CHANGE}

# Clone Sahara
git clone https://review.openstack.org/openstack/sahara $SAHARA_PATH -b $ZUUL_BRANCH

# make verbose the scripts execution of disk-image-create
export DIB_DEBUG_TRACE=1

case $job_type in
    vanilla_2.6)
       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username='ubuntu'
       fi

       env ${image_type}_vanilla_hadoop_2_6_image_name=${vanilla_two_six_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p vanilla -i $image_type -v 2.6
       check_error_code $? ${vanilla_two_six_image}.qcow2
       upload_image "vanilla-2.6" "${username}" ${vanilla_two_six_image}
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/vanilla-2.6.0.yaml"
       insert_scenario_value $tests_config_file vanilla_two_six_image
    ;;

    spark)
       env ubuntu_spark_image_name=${spark_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p spark
       check_error_code $? ${spark_image}.qcow2
       upload_image "spark" "ubuntu" ${spark_image}
       tests_config_file="$sahara_templates_path/spark-1.0.0.yaml"
       insert_scenario_value $tests_config_file spark_image
       insert_config_value $sahara_conf_path DEFAULT plugins spark
    ;;

    hdp_2)
       env centos_hdp_hadoop_2_image_name=${hdp_two_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p hdp -v 2
       check_error_code $? ${hdp_two_image}.qcow2
       upload_image "hdp2" "cloud-user" ${hdp_two_image}
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/hdp-2.0.6.yaml"
       insert_scenario_value $tests_config_file hdp_two_image
    ;;

    cdh_5.3.0)
       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username='ubuntu'
       fi
       env cloudera_5_3_${image_type}_image_name=${cdh_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p cloudera -i $image_type -v 5.3
       check_error_code $? ${cdh_image}.qcow2
       upload_image "cdh_5.3.0" ${username} ${cdh_image}
       tests_config_file="$sahara_templates_path/cdh-5.3.0.yaml"
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       insert_scenario_value $tests_config_file cdh_image
    ;;

    cdh_5.4.0)
       env cloudera_5_4_ubuntu_image_name=${cdh_5_4_0_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p cloudera -i ubuntu -v 5.4
       check_error_code $? ${cdh_5_4_0_image}.qcow2
       upload_image "cdh_5.4.0" "ubuntu" ${cdh_5_4_0_image}
       tests_config_file="$sahara_templates_path/cdh-5.4.0.yaml"
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       insert_scenario_value $tests_config_file cdh_5_4_0_image
    ;;

    mapr)
       env mapr_ubuntu_image_name=${mapr_402mrv2_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p mapr -i ubuntu
       check_error_code $? ${mapr_402mrv2_image}.qcow2
       upload_image "mapr" "ubuntu" ${mapr_402mrv2_image}
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/mapr-4.0.2.mrv2.yaml"
       insert_config_value $sahara_conf_path DEFAULT plugins mapr
       insert_scenario_value $tests_config_file mapr_402mrv2_image
    ;;
esac

cd $SAHARA_PATH
sudo pip install . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_path" "$engine"
write_tests_conf "$tests_config_file" "$cluster_name"
start_sahara "$sahara_conf_path" && run_tests "$tests_config_file"
print_python_env
cleanup_image "$job_type" "$image_type"
