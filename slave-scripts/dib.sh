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
plugin="$1"
os="$2"
${plugin}_image=${HOST}_${plugin}_${os}_${ZUUL_CHANGE}

# Clone Sahara
git clone https://review.openstack.org/openstack/sahara $SAHARA_PATH -b $ZUUL_BRANCH

# make verbose the scripts execution of disk-image-create
export DIB_DEBUG_TRACE=1

if [ "${os}" == 'c6.6' ]; then
    username="cloud-user"
    os_type="centos"
else
    username="ubuntu"
    os_type="ubuntu"
fi

case $plugin in
    vanilla_1.2.1)
       env ${os_type}_vanilla_hadoop_1_image_name=${vanilla_1_2_1_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p vanilla -i $os_type -v 1
       check_error_code $? ${vanilla_1_2_1_image}.qcow2
       upload_image "${plugin}" "${username}" ${vanilla_1_2_1_image}
       tests_config_file="$sahara_templates_path/vanilla-1.2.1.yaml"
       insert_scenario_value $tests_config_file vanilla_1_2_1_image
    ;;

    vanilla_2.6.0)
       env ${os_type}_vanilla_hadoop_2_6_image_name=${vanilla_2_6_0_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p vanilla -i $os_type -v 2.6
       check_error_code $? ${vanilla_2_6_0_image}.qcow2
       upload_image "${plugin}" "${username}" ${vanilla_2_6_0_image}
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/vanilla-2.6.0.yaml"
       insert_scenario_value $tests_config_file vanilla_2_6_0_image
    ;;

    spark_1.0.0)
       env ubuntu_spark_image_name=${spark_1_0_0_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p spark
       check_error_code $? ${spark_1_0_0_image}.qcow2
       upload_image "${plugin}" "ubuntu" ${spark_1_0_0_image}
       tests_config_file="$sahara_templates_path/spark-1.0.0.yaml"
       insert_config_value $sahara_conf_path DEFAULT plugins spark
       insert_scenario_value $tests_config_file spark_1_0_0_image
    ;;

    hdp_1.3.2)
       env centos_hdp_hadoop_1_image_name=${hdp_1_3_2_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p hdp -v 1
       check_error_code $? ${hdp_1_3_2_image}.qcow2
       upload_image "${plugin}" "root" ${hdp_1_3_2_image}
       tests_config_file="$sahara_templates_path/hdp-1.3.2.yaml"
       insert_scenario_value $tests_config_file hdp_1_3_2_image
    ;;

    hdp_2.0.6)
       env centos_hdp_hadoop_2_image_name=${hdp_2_0_6_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p hdp -v 2
       check_error_code $? ${hdp_2_0_6_image}.qcow2
       upload_image "${plugin}" "root" ${hdp_2_0_6_image}
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/hdp-2.0.6.yaml"
       insert_scenario_value $tests_config_file hdp_2_0_6_image
    ;;

    cdh_5.3.0)
       env cloudera_5_3_${os_type}_image_name=${cdh_5_3_0_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p cloudera -i $os_type -v 5.3
       check_error_code $? ${cdh_5_3_0_image}.qcow2
       upload_image "${plugin}" "${username}" ${cdh_5_3_0_image}
       tests_config_file="$sahara_templates_path/cdh-5.3.0.yaml"
       insert_config_value $sahara_conf_path DEFAULT plugins cdh
       insert_scenario_value $tests_config_file cdh_5_3_0_image
    ;;

    mapr_4.0.2.mrv2)
       env mapr_ubuntu_image_name=${mapr_4_0_2_mrv2_image} SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p mapr -i ubuntu
       check_error_code $? ${mapr_4_0_2_mrv2_image}.qcow2
       upload_image "${plugin}" "ubuntu" ${mapr_4_0_2_mrv2_image}
       DISTRIBUTE_MODE=True
       tests_config_file="$sahara_templates_path/mapr-4.0.2.mrv2.yaml"
       insert_config_value $sahara_conf_path DEFAULT plugins mapr
       insert_scenario_value $tests_config_file mapr_4_0_2_mrv2_image
    ;;
esac

cd $SAHARA_PATH
sudo pip install . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_path" "$engine"
write_tests_conf "$tests_config_file" "$cluster_name"
start_sahara "$sahara_conf_path" && run_tests "$tests_config_file"
print_python_env
cleanup_image "$plugin" "$os"
