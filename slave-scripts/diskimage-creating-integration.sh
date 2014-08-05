#!/bin/bash

RELEASE_DIB="0.1.17"
NETWORK=`ifconfig eth0 | awk -F ' *|:' '/inet addr/{print $4}' | awk -F . '{print $2}'`
if [ "$NETWORK" == "0" ]; then
    OPENSTACK_HOST="172.18.168.42"
    HOST="c1"
    TENANT_ID="$CI_LAB_TENANT_ID"
else
    OPENSTACK_HOST="172.18.168.43"
    HOST="c2"
    TENANT_ID="$STACK_SAHARA_TENANT_ID"
fi

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
             glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
           2.3)
             glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.3.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
           2.4)
             glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.4.1'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
   esac
}

register_hdp_image() {
   # 1 - hadoop version, 2 - username, 3 - image name
   case "$1" in
           1)
             glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.3.2'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'="${2}"
             ;;
           2)
             glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.0.6'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'="${2}"
             ;;
   esac
}

register_cdh_image() {
   # 1 - username, 2 - image name
   glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $2 --file $2.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="${1}"
}

delete_image() {
   glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete $1
}

upload_image() {
   # 1 - plugin, 2 - username, 3 - image name
   delete_image $3

   case "$1" in
           vanilla-1)
             register_vanilla_image "1" "$2" "$3"
           ;;
           vanilla-2.3)
             register_vanilla_image "2.3" "$2" "$3"
           ;;
           vanilla-2.4)
             register_vanilla_image "2.4" "$2" "$3"
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
   esac
}

rename_image() {
   # 1 - source image, 2 - target image
   glance --os-username ci-user --os-auth-url http://$OPENSTACK_HOST:5000/v2.0/ --os-tenant-name ci --os-password nova image-update $1 --name $2
}

plugin="$1"
image_type=${2:-ubuntu}
hadoop_version=${3:-1}
TIMEOUT=60
GERRIT_CHANGE_NUMBER=$ZUUL_CHANGE
SKIP_CINDER_TEST=True
SKIP_CLUSTER_CONFIG_TEST=True
SKIP_EDP_TEST=False
SKIP_MAP_REDUCE_TEST=False
SKIP_SWIFT_TEST=True
SKIP_SCALING_TEST=True
SKIP_TRANSIENT_TEST=True
VANILLA_IMAGE=$HOST-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1
VANILLA_TWO_IMAGE=$HOST-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2
HDP_IMAGE=$HOST-sahara-hdp-centos-${GERRIT_CHANGE_NUMBER}-hadoop_1
HDP_TWO_IMAGE=$HOST-sahara-hdp-centos-${GERRIT_CHANGE_NUMBER}-hadoop_2
SPARK_IMAGE=$HOST-sahara-spark-ubuntu-${GERRIT_CHANGE_NUMBER}
SSH_USERNAME="ubuntu"
CDH_IMAGE=$HOST-ubuntu-cdh-${GERRIT_CHANGE_NUMBER}

case $plugin in
    vanilla)
       pushd /home/jenkins
       python -m SimpleHTTPServer 8000 > /dev/null &
       popd

       if [ "${image_type}" == 'centos' ]; then
           username='cloud-user'
       else
           username=${image_type}
       fi
       SSH_USERNAME=${username}

       case $hadoop_version in
           1)
              sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder-$RELEASE_DIB" ${image_type}_vanilla_hadoop_1_image_name=${VANILLA_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 1
              check_error_code $? ${VANILLA_IMAGE}.qcow2
              upload_image "vanilla-1" "${username}" ${VANILLA_IMAGE}
              ;;
           2.3)
              sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder-$RELEASE_DIB" ${image_type}_vanilla_hadoop_2_3_image_name=${VANILLA_TWO_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2.3
              check_error_code $? ${VANILLA_TWO_IMAGE}.qcow2
              upload_image "vanilla-2.3" "${username}" ${VANILLA_TWO_IMAGE}
              hadoop_version=2-3
              ;;
           2.4)
              sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder-$RELEASE_DIB" ${image_type}_vanilla_hadoop_2_4_image_name=${VANILLA_TWO_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2.4
              check_error_code $? ${VANILLA_TWO_IMAGE}.qcow2
              upload_image "vanilla-2.4" "${username}" ${VANILLA_TWO_IMAGE}
              hadoop_version=2-4
              ;;
       esac
    ;;

    spark)
       pushd /home/jenkins
       python -m SimpleHTTPServer 8000 > /dev/null &
       popd

       image_type="ubuntu"
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder-$RELEASE_DIB" ${image_type}_spark_image_name=${SPARK_IMAGE} JAVA_DOWNLOAD_URL='http://127.0.0.1:8000/jdk-7u51-linux-x64.tar.gz' SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p "spark"
       check_error_code $? ${SPARK_IMAGE}.qcow2
       exit 0
    ;;

    hdp1)
       image_type="centos"
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder-$RELEASE_DIB" ${image_type}_hdp_hadoop_1_image_name=${HDP_IMAGE} SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p hdp -v 1
       check_error_code $? ${HDP_IMAGE}.qcow2
       SSH_USERNAME="root"
       upload_image "hdp1" "root" ${HDP_IMAGE}
    ;;

    hdp2)
       image_type="centos"
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder-$RELEASE_DIB" ${image_type}_hdp_hadoop_2_image_name=${HDP_TWO_IMAGE} SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p hdp -v 2
       check_error_code $? ${HDP_TWO_IMAGE}.qcow2
       SSH_USERNAME="root"
       upload_image "hdp2" "root" ${HDP_TWO_IMAGE}
       hadoop_version="2"
    ;;

    cdh)
       image_type="ubuntu"
       sudo DIB_REPO_PATH="/home/jenkins/diskimage-builder-$RELEASE_DIB" cloudera_ubuntu_image_name=${CDH_IMAGE} SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p cloudera -i ubuntu
       check_error_code $? ${CDH_IMAGE}.qcow2
       upload_image "cdh" "ubuntu" ${CDH_IMAGE}
       SSH_USERNAME="ubuntu"
       hadoop_version="2"
    ;;
esac

# This parameter is used for cluster name, because cluster name's length exceeds limit 64 characters with $image_type.
image_os="uOS"
if [ "$image_type" == "centos" ]; then
    image_os="cOS"
fi
if [ "$image_type" == "fedora" ]; then
    image_os="fOS"
fi

# Run test
export PYTHONUNBUFFERED=1

cd /tmp/

TOX_LOG=/tmp/sahara/.tox/venv/log/venv-1.log
TMP_LOG=/tmp/tox.log
LOG_FILE=/tmp/tox_log.log

SCR_CHECK=$(ps aux | grep screen | grep sahara)
if [ -n "$SCR_CHECK" ]; then
     screen -S sahara-all -X quit
fi

rm -rf /tmp/cache
rm -f $LOG_FILE

mysql -usahara-citest -psahara-citest -Bse "DROP DATABASE IF EXISTS sahara"
mysql -usahara-citest -psahara-citest -Bse "create database sahara"

BUILD_ID=dontKill
#sudo pip install tox
mkdir /tmp/cache

export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

sudo rm -rf sahara
git clone https://review.openstack.org/openstack/sahara
cd sahara
sudo pip install .

echo "[DEFAULT]
" >> etc/sahara/sahara.conf

echo "infrastructure_engine=direct
" >> etc/sahara/sahara.conf

if [ "$plugin" == "cdh" ]
then
    echo "plugins=vanilla,hdp,cdh
" >> etc/sahara/sahara.conf
fi

echo "
os_auth_host=$OPENSTACK_HOST
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_identity_api_v3=true
use_neutron=true
node_domain = nl
[database]
connection=mysql://sahara-citest:sahara-citest@localhost/sahara?charset=utf8
[keystone_authtoken]
auth_uri=http://$OPENSTACK_HOST:5000/v2.0/
identity_uri=http://$OPENSTACK_HOST:35357/
admin_user=ci-user
admin_password=nova
admin_tenant_name=ci" >> etc/sahara/sahara.conf

echo "----------- sahara.conf -----------"
cat etc/sahara/sahara.conf
echo "----------- end of sahara.conf -----------"

#touch ~/.pip/pip.conf

#echo "
#[global]
#timeout = 60
#index-url = http://sahara-ci.vm.mirantis.net/pypi/sahara/
#extra-index-url = https://pypi.python.org/simple/
#download-cache = /home/ubuntu/.pip/cache/
#[install]
#use-mirrors = true
#find-links = http://sahara-ci.vm.mirantis.net:8181/simple/
#" > ~/.pip/pip.conf
echo "
[global]
timeout = 60
index-url = https://sahara.mirantis.com/pypi/
extra-index-url = http://pypi.openstack.org/openstack/
download-cache = /home/jenkins/.pip/cache/
[install]
use-mirrors = true
" > ~/.pip/pip.conf

echo "
[easy_install]
index_url = https://sahara.mirantis.com/pypi/
" > ~/.pydistutils.cfg

sahara-db-manage --config-file etc/sahara/sahara.conf upgrade head

screen -dmS sahara-all /bin/bash -c "PYTHONUNBUFFERED=1 sahara-all --config-file etc/sahara/sahara.conf -d --log-file log.txt | tee /tmp/tox-log.txt"

cd /tmp/sahara
export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

echo "[COMMON]
OS_USERNAME = 'ci-user'
OS_PASSWORD = 'nova'
OS_TENANT_NAME = 'ci'
OS_TENANT_ID = '$TENANT_ID'
OS_AUTH_URL = 'http://$OPENSTACK_HOST:5000/v2.0'
SAHARA_HOST = '$ADDR'
FLAVOR_ID = '20'
CLUSTER_CREATION_TIMEOUT = $TIMEOUT
CLUSTER_NAME = '$HOST-$image_os-$hadoop_version-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET'
FLOATING_IP_POOL = 'public'
NEUTRON_ENABLED = True
INTERNAL_NEUTRON_NETWORK = 'private'
JOB_LAUNCH_TIMEOUT = 15
HDFS_INITIALIZATION_TIMEOUT = 10
$COMMON_PARAMS
" >> sahara/tests/integration/configs/itest.conf

echo "[VANILLA]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$VANILLA_IMAGE'
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_CLUSTER_CONFIG_TEST = $SKIP_CLUSTER_CONFIG_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_TRANSIENT_CLUSTER_TEST = $SKIP_TRANSIENT_TEST
$VANILLA_PARAMS
" >> sahara/tests/integration/configs/itest.conf

echo "[VANILLA_TWO]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$VANILLA_TWO_IMAGE'
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
$VANILLA_PARAMS
" >> sahara/tests/integration/configs/itest.conf

if [ "$plugin" == "vanilla" -a "$hadoop_version" == "2-4" ]; then
   echo "HADOOP_VERSION = '2.4.1'
SKIP_EDP_JOB_TYPES = Pig
HADOOP_EXAMPLES_JAR_PATH = '/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.4.1.jar'
" >> sahara/tests/integration/configs/itest.conf
fi

echo "[HDP]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
$HDP_PARAMS
" >> sahara/tests/integration/configs/itest.conf

echo "[HDP2]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP_TWO_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
" >> sahara/tests/integration/configs/itest.conf

echo "[CDH]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$CDH_IMAGE'
" >> $WORKSPACE/sahara/tests/integration/configs/itest.conf

touch $TMP_LOG
API_RESPONDING_TIMEOUT=30
FAILURE=0

if ! timeout ${API_RESPONDING_TIMEOUT} sh -c "while ! curl -s http://127.0.0.1:8386/v1.1/ 2>/dev/null | grep -q 'Authentication required' ; do sleep 1; done"; then
    echo "Sahara API failed to respond within ${API_RESPONDING_TIMEOUT} seconds"
    FAILURE=1
fi

if [ "$FAILURE" = 0 ]; then

    export PYTHONUNBUFFERED=1

    cd /tmp/sahara
    if [ "${plugin}" == "vanilla" ]; then
        if [ "${hadoop_version}" == "1" ]; then
           tox -e integration -- vanilla1 --concurrency=1
           STATUS=`echo $?`
        else
           tox -e integration -- vanilla2 --concurrency=1
           STATUS=`echo $?`
        fi
    fi
    if [ "${plugin}" == "hdp1" ]; then
        tox -e integration -- hdp1 --concurrency=1
        STATUS=`echo $?`
    fi
    if [ "${plugin}" == "hdp2" ]; then
        tox -e integration -- hdp2 --concurrency=1
        STATUS=`echo $?`
    fi
    if [ "${plugin}" == "cdh" ]
    then
        tox -e integration -- cdh --concurrency=1
        STATUS=`echo $?`
    fi
fi

echo "-----------Python integration env-----------"
cd /tmp/sahara && .tox/integration/bin/pip freeze

screen -S sahara-all -X quit

echo "-----------Python sahara env-----------"
cd /tmp/sahara && pip freeze

echo "-----------Sahara Log------------"
cat /tmp/sahara/log.txt
rm -rf /tmp/sahara
rm -rf /tmp/cache/

echo "-----------Tox log-----------"
cat /tmp/tox-log.txt
rm -f /tmp/tox-log.txt

rm $TMP_LOG
rm -f $LOG_FILE
cd $HOME

if [ "$FAILURE" != 0 ]; then
    exit 1
fi

if [[ "$STATUS" != 0 ]]
then
    if [ "${plugin}" == "vanilla" ]; then
        if [ "${hadoop_version}" == "1" ]; then
            delete_image $VANILLA_IMAGE
        else
            delete_image $VANILLA_TWO_IMAGE
        fi
    fi
    if [ "${plugin}" == "hdp1" ]; then
        delete_image $HDP_IMAGE
    fi
    if [ "${plugin}" == "hdp2" ]; then
        delete_image $HDP_TWO_IMAGE
    fi
    if [ "${plugin}" == "cdh" ]; then
        delete_image $CDH_IMAGE
    fi
    exit 1
fi

if [ "$ZUUL_PIPELINE" == "check" ]
then
    if [ "${plugin}" == "vanilla" ]; then
        if [ "${hadoop_version}" == "1" ]; then
            delete_image $VANILLA_IMAGE
        else
            delete_image $VANILLA_TWO_IMAGE
        fi
    fi
    if [ "${plugin}" == "hdp1" ]; then
        delete_image $HDP_IMAGE
    fi
    if [ "${plugin}" == "hdp2" ]; then
        delete_image $HDP_TWO_IMAGE
    fi
    if [ "${plugin}" == "cdh" ]; then
        delete_image $CDH_IMAGE
    fi
else
    if [ "${plugin}" == "vanilla" ]; then
        if [ "${hadoop_version}" == "1" ]; then
            delete_image ${image_type}_sahara_vanilla_hadoop_1_latest
            rename_image $VANILLA_IMAGE ${image_type}_sahara_vanilla_hadoop_1_latest
        else
            delete_image ${image_type}_sahara_vanilla_hadoop_${hadoop_version}_latest
            rename_image $VANILLA_TWO_IMAGE ${image_type}_sahara_vanilla_hadoop_${hadoop_version}_latest
        fi
    fi
    if [ "${plugin}" == "hdp1" ]; then
        delete_image centos_sahara_hdp_hadoop_1_latest
        rename_image $HDP_IMAGE centos_sahara_hdp_hadoop_1_latest
    fi
    if [ "${plugin}" == "hdp2" ]; then
        delete_image centos_sahara_hdp_hadoop_2_latest
        rename_image $HDP_TWO_IMAGE centos_sahara_hdp_hadoop_2_latest
    fi
    if [ "${plugin}" == "cdh" ]; then
        delete_image ubuntu_cdh_latest
        rename_image $CDH_IMAGE ubuntu_cdh_latest
    fi
fi
