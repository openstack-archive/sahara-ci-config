#!/bin/bash

. $FUNCTION_PATH

check_openstack_host

check_error_code() {
   if [ "$1" != "0" -o ! -f "$2" ]; then
       echo "$2 image doesn't build"
       exit 1
   fi
}

register_vanilla_image() {
   # 1 - hadoop version, 2 - username, 3 - image name
   case "$1" in
           1)
             glance image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
           2.4)
             glance image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.4.1'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
           2.6)
             glance image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.6.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
   esac
}

register_hdp_image() {
   # 1 - hadoop version, 2 - username, 3 - image name
   case "$1" in
           1)
             glance image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.3.2'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'="${2}"
             ;;
           2)
             glance image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.0.6'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'="${2}"
             ;;
   esac
}

register_cdh_image() {
   # 1 - username, 2 - image name
   glance image-create --name $2 --file $2.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5.3.0'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="${1}"
}

register_spark_image() {
   # 1 - username, 2 - image name
   glance image-create --name $2 --file $2.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_spark'='True' --property '_sahara_tag_1.0.0'='True'  --property '_sahara_username'="${1}"
}

delete_image() {
   glance image-delete $1
}

upload_image() {
   # 1 - plugin, 2 - username, 3 - image name
   delete_image $3

   case "$1" in
           vanilla-1)
             register_vanilla_image "1" "$2" "$3"
           ;;
           vanilla-2.4)
             register_vanilla_image "2.4" "$2" "$3"
           ;;
           vanilla-2.6)
             register_vanilla_image "2.6" "$2" "$3"
           ;;
           hdp1)
             register_hdp_image "1" "$2" "$3"
           ;;
           hdp2)
             register_hdp_image "2" "$2" "$3"
           ;;
           cdh)
             register_cdh_image "$2" "$3"
           ;;
           spark)
             register_spark_image "$2" "$3"
           ;;
   esac
}

rename_image() {
   # 1 - source image, 2 - target image
   glance image-update $1 --name $2
}

ENGINE_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $3 }')

plugin="$1"
image_type=${2:-ubuntu}
hadoop_version=1
GERRIT_CHANGE_NUMBER=$ZUUL_CHANGE
SKIP_CINDER_TEST=True
SKIP_CLUSTER_CONFIG_TEST=True
SKIP_EDP_TEST=False
SKIP_MAP_REDUCE_TEST=True
SKIP_SWIFT_TEST=True
SKIP_SCALING_TEST=True
SKIP_TRANSIENT_TEST=True
SKIP_ONLY_TRANSIENT_TEST=False
SKIP_ALL_TESTS_FOR_PLUGIN=False
VANILLA_IMAGE=$HOST-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1
VANILLA_TWO_IMAGE=$HOST-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2
HDP_IMAGE=$HOST-sahara-hdp-centos-${GERRIT_CHANGE_NUMBER}-hadoop_1
HDP_TWO_IMAGE=$HOST-sahara-hdp-centos-${GERRIT_CHANGE_NUMBER}-hadoop_2
SPARK_IMAGE=$HOST-sahara-spark-ubuntu-${GERRIT_CHANGE_NUMBER}
CDH_IMAGE=$HOST-${image_type}-cdh-${GERRIT_CHANGE_NUMBER}
TESTS_CONFIG_FILE='sahara/tests/integration/configs/itest.conf'

if [[ "$ENGINE_TYPE" == 'heat' ]]
then
    HEAT_JOB=True
    echo "Heat detected"
fi

case $plugin in
    vanilla*)
       pushd /home/jenkins
       python -m SimpleHTTPServer 8000 > /dev/null &
       popd

       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username=${image_type}
       fi

       hadoop_version=$(echo $plugin | awk -F '_' '{print $2}')
       case $hadoop_version in
           1)
              sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder" ${image_type}_vanilla_hadoop_1_image_name=${VANILLA_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 1
              check_error_code $? ${VANILLA_IMAGE}.qcow2
              upload_image "vanilla-1" "${username}" ${VANILLA_IMAGE}
              PLUGIN_TYPE=vanilla1
              ;;
           2.4)
              VANILLA_TWO_IMAGE=$HOST-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2.4
              [ "$ZUUL_BRANCH" == "stable/icehouse" ] && echo "Vanilla 2.4 plugin is not supported in stable/icehouse" && exit 0
              sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder" ${image_type}_vanilla_hadoop_2_4_image_name=${VANILLA_TWO_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2.4
              check_error_code $? ${VANILLA_TWO_IMAGE}.qcow2
              upload_image "vanilla-2.4" "${username}" ${VANILLA_TWO_IMAGE}
              hadoop_version=2-4
              PLUGIN_TYPE=vanilla2
              ;;
           2.6)
              VANILLA_TWO_IMAGE=$HOST-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2.6
              [ "$ZUUL_BRANCH" == "stable/icehouse" -o "$ZUUL_BRANCH" == "stable/juno" ] && echo "Vanilla 2.6 plugin is not supported in stable/icehouse and stable/juno" && exit 0
              sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder" ${image_type}_vanilla_hadoop_2_6_image_name=${VANILLA_TWO_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2.6
              check_error_code $? ${VANILLA_TWO_IMAGE}.qcow2
              upload_image "vanilla-2.6" "${username}" ${VANILLA_TWO_IMAGE}
              hadoop_version=2-6
              PLUGIN_TYPE=vanilla2
              # Skipping hive job check for fedora and centos images because it's causing the test failure
              if [ "$image_type" != "ubuntu" ] ; then
                  SKIP_EDP_JOB_TYPES=Hive
              fi
              TESTS_CONFIG_FILE="$WORKSPACE/sahara-ci-config/config/sahara/sahara-test-config-vanilla-2.6.yaml"
              ;;
       esac
    ;;

    spark)
       pushd /home/jenkins
       python -m SimpleHTTPServer 8000 > /dev/null &
       popd

       image_type="ubuntu"
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder" ${image_type}_spark_image_name=${SPARK_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p "spark"
       check_error_code $? ${SPARK_IMAGE}.qcow2
       [ "$ZUUL_BRANCH" == "stable/icehouse" ] && echo "Tests for Spark plugin is not implemented in stable/icehouse" && exit 0
       upload_image "spark" "ubuntu" ${SPARK_IMAGE}
       PLUGIN_TYPE=$plugin
       [ "$ZUUL_BRANCH" == "master" ] && TESTS_CONFIG_FILE="$WORKSPACE/sahara-ci-config/config/sahara/sahara-test-config-spark.yaml"
    ;;

    hdp_1)
       image_type="centos"
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder" ${image_type}_hdp_hadoop_1_image_name=${HDP_IMAGE} SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p hdp -v 1
       check_error_code $? ${HDP_IMAGE}.qcow2
       upload_image "hdp1" "root" ${HDP_IMAGE}
       PLUGIN_TYPE="hdp1"
    ;;

    hdp_2)
       image_type="centos"
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder" ${image_type}_hdp_hadoop_2_image_name=${HDP_TWO_IMAGE} SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p hdp -v 2
       check_error_code $? ${HDP_TWO_IMAGE}.qcow2
       upload_image "hdp2" "root" ${HDP_TWO_IMAGE}
       hadoop_version="2"
       PLUGIN_TYPE="hdp2"
    ;;

    cdh)
       [ "$ZUUL_BRANCH" == "stable/icehouse" ] && echo "CDH plugin is not supported in stable/icehouse" && exit 0
       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username='ubuntu'
       fi
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder" cloudera_5_3_${image_type}_image_name=${CDH_IMAGE} SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p cloudera -i $image_type -v 5.3
       check_error_code $? ${CDH_IMAGE}.qcow2
       upload_image "cdh" ${username} ${CDH_IMAGE}
       hadoop_version="2"
       PLUGIN_TYPE=$plugin
    ;;
esac

# This parameter is used for cluster name, because cluster name's length exceeds limit 64 characters with $image_type.
image_os="uos"
if [ "$image_type" == "centos" ]; then
    image_os="cos"
elif [ "$image_type" == "fedora" ]; then
    image_os="fos"
fi

cd /tmp/
TOX_LOG=/tmp/sahara/.tox/venv/log/venv-1.log

create_database

sudo rm -rf sahara
git clone https://review.openstack.org/openstack/sahara
cd sahara
[ "$ZUUL_BRANCH" == "stable/icehouse" ] && sudo pip install -U -r requirements.txt
sudo pip install .

enable_pypi

write_sahara_main_conf etc/sahara/sahara.conf
start_sahara etc/sahara/sahara.conf

cd /tmp/sahara

CLUSTER_NAME="$HOST-$image_os-$hadoop_version-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET"
write_tests_conf

run_tests

print_python_env /tmp/sahara

mv /tmp/sahara/logs $WORKSPACE

if [ "$FAILURE" != 0 ]; then
    exit 1
fi

if [[ "$STATUS" != 0 ]]
then
    if [[ "${plugin}" =~ vanilla ]]; then
        if [ "${hadoop_version}" == "1" ]; then
            delete_image $VANILLA_IMAGE
        else
            delete_image $VANILLA_TWO_IMAGE
        fi
    fi
    if [ "${plugin}" == "hdp_1" ]; then
        delete_image $HDP_IMAGE
    fi
    if [ "${plugin}" == "hdp_2" ]; then
        delete_image $HDP_TWO_IMAGE
    fi
    if [ "${plugin}" == "cdh" ]; then
        delete_image $CDH_IMAGE
    fi
    if [ "${plugin}" == "spark" ]; then
        delete_image $SPARK_IMAGE
    fi
    exit 1
fi

if [ "$ZUUL_PIPELINE" == "check" -o "$ZUUL_BRANCH" != "master" ]
then
    if [[ "${plugin}" =~ vanilla ]]; then
        if [ "${hadoop_version}" == "1" ]; then
            delete_image $VANILLA_IMAGE
        else
            delete_image $VANILLA_TWO_IMAGE
        fi
    fi
    if [ "${plugin}" == "hdp_1" ]; then
        delete_image $HDP_IMAGE
    fi
    if [ "${plugin}" == "hdp_2" ]; then
        delete_image $HDP_TWO_IMAGE
    fi
    if [ "${plugin}" == "cdh" ]; then
        delete_image $CDH_IMAGE
    fi
    if [ "${plugin}" == "spark" ]; then
        delete_image $SPARK_IMAGE
    fi
else
    if [[ "${plugin}" =~ vanilla ]]; then
        hadoop_version=$(echo $plugin | awk -F '_' '{print $2}')
        if [ "${hadoop_version}" == "1" ]; then
            delete_image ${image_type}_vanilla_1_latest
            rename_image $VANILLA_IMAGE ${image_type}_vanilla_1_latest
        else
            delete_image ${image_type}_vanilla_${hadoop_version}_latest
            rename_image $VANILLA_TWO_IMAGE ${image_type}_vanilla_${hadoop_version}_latest
        fi
    fi
    if [ "${plugin}" == "hdp_1" ]; then
        delete_image sahara_hdp_1_latest
        rename_image $HDP_IMAGE sahara_hdp_1_latest
    fi
    if [ "${plugin}" == "hdp_2" ]; then
        delete_image sahara_hdp_2_latest
        rename_image $HDP_TWO_IMAGE sahara_hdp_2_latest
    fi
    if [ "${plugin}" == "cdh" ]; then
        delete_image ${image_type}_cdh_latest
        rename_image $CDH_IMAGE ${image_type}_cdh_latest
    fi
    if [ "${plugin}" == "spark" ]; then
        delete_image sahara_spark_latest
        rename_image $SPARK_IMAGE sahara_spark_latest
    fi
fi
