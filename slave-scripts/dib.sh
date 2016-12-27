#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source functions
. $FUNCTION_PATH/functions-common.sh
. $FUNCTION_PATH/functions-dib.sh

CLUSTER_HASH=${CLUSTER_HASH:-$RANDOM}
cluster_name="$HOST-$ZUUL_CHANGE-$CLUSTER_HASH"

SAHARA_PATH="/tmp/sahara"
SAHARA_TESTS_PATH="/tmp/sahara-tests"
sahara_conf_file="$SAHARA_PATH/etc/sahara/sahara.conf"
sahara_templates_path=$SAHARA_TESTS_PATH/sahara_tests/scenario/defaults
export tests_etc=$sahara_templates_path

plugin="$1"
os="$2"
image_name=${HOST}_${plugin}_${os}_${ZUUL_CHANGE}
eval ${plugin//./_}_image=$image_name
sahara_plugin=$(echo $plugin | awk -F '_' '{ print $1 } ')

# Clone Sahara
get_dependency "$SAHARA_PATH" "openstack/sahara" "$ZUUL_BRANCH"

# Clone Sahara Scenario tests
get_dependency "$SAHARA_TESTS_PATH" "openstack/sahara-tests" "master"

# make verbose the scripts execution of disk-image-create
export DIB_DEBUG_TRACE=1
export DIB_MIN_TMPFS=4
echo "127.0.0.1 $HOSTNAME"|  sudo tee -a /etc/hosts

case "${os}" in
    c6.6)
        username="cloud-user"
        os_type="centos"
        ;;
    c7)
        username="centos"
        os_type="centos7"
        ;;
    u12 | u14)
        username="ubuntu"
        os_type="ubuntu"
        ;;
    *)
        echo "Unrecognized OS: ${os}" >&2
        exit 1
        ;;
esac

scenario_conf_file=$(get_template_path $ZUUL_BRANCH $plugin $sahara_templates_path)

case $plugin in
    vanilla_2.7.1)
      env ${os_type}_vanilla_hadoop_2_7_1_image_name="${vanilla_2_7_1_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p vanilla -i $os_type -v 2.7.1
      check_error_code $? "${vanilla_2_7_1_image:?}".qcow2
      upload_image "${plugin}" "${username}" "${vanilla_2_7_1_image:?}"
    ;;

    spark_1.6.0)
       env ubuntu_spark_image_name="${spark_1_6_0_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p spark -s 1.6.0
       check_error_code $? "${spark_1_6_0_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${spark_1_6_0_image:?}"
    ;;

    cdh_5.5.0)
       env cloudera_5_5_${os_type}_image_name="${cdh_5_5_0_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p cloudera -i $os_type -v 5.5
       check_error_code $? "${cdh_5_5_0_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${cdh_5_5_0_image:?}"
    ;;

    cdh_5.7.0)
       env cloudera_5_7_${os_type}_image_name="${cdh_5_7_0_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p cloudera -i $os_type -v 5.7
       check_error_code $? "${cdh_5_7_0_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${cdh_5_7_0_image:?}"
    ;;

    cdh_5.9.0)
       env cloudera_5_9_${os_type}_image_name="${cdh_5_9_0_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p cloudera -i $os_type -v 5.9
       check_error_code $? "${cdh_5_9_0_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${cdh_5_9_0_image:?}"
    ;;

    ambari_2.2)
       env ambari_${os_type}_image_name="${ambari_2_2_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p ambari -i $os_type
       check_error_code $? "${ambari_2_2_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${ambari_2_2_image:?}"
       # we use Ambari 2.1 management console for creating HDP 2.3 stack
       scenario_conf_file="$sahara_templates_path/ambari-2.3.yaml.mako"
    ;;

    mapr_5.1.0.mrv2)
       env mapr_ubuntu_image_name="${mapr_5_1_0_mrv2_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p mapr -i ubuntu -r 5.1.0
       check_error_code $? "${mapr_5_1_0_mrv2_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${mapr_5_1_0_mrv2_image:?}"
    ;;

    mapr_5.2.0.mrv2)
       env mapr_ubuntu_image_name="${mapr_5_2_0_mrv2_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p mapr -i ubuntu -r 5.2.0
       check_error_code $? "${mapr_5_2_0_mrv2_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${mapr_5_2_0_mrv2_image:?}"
    ;;

    storm_1.0.1)
       env ubuntu_storm_image_name="${storm_1_0_1_image:?}" SIM_REPO_PATH=$WORKSPACE tox -e venv -- sahara-image-create -p storm -t 1.0.1
       check_error_code $? "${storm_1_0_1_image:?}".qcow2
       upload_image "${plugin}" "${username}" "${storm_1_0_1_image:?}"
    ;;
esac

cd $SAHARA_PATH
sudo pip install . --no-cache-dir
enable_pypi
write_sahara_main_conf "$sahara_conf_file" "$sahara_plugin"
write_tests_conf "$cluster_name" "$image_name" "$scenario_conf_file"
start_sahara "$sahara_conf_file" && run_tests "$scenario_conf_file"
print_python_env
cleanup_image "$plugin" "$os"
