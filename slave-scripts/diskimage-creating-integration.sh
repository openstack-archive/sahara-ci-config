#!/bin/bash

image_type=$1
GERRIT_CHANGE_NUMBER=$ZUUL_CHANGE


sudo SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 1
sudo SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2

if [ ${image_type} == "ubuntu" ]
then
     if [ ! -f ${image_type}_sahara_vanilla_hadoop_1_latest.qcow2 -o ! -f ${image_type}_sahara_vanilla_hadoop_2_latest.qcow2 ]; then
       echo "Images aren't built"
       exit 1
     fi
     mv ${image_type}_sahara_vanilla_hadoop_1_latest.qcow2 ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1.qcow2
     mv ${image_type}_sahara_vanilla_hadoop_2_latest.qcow2 ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2.qcow2
else
     if [ ! -f ${image_type}_sahara_vanilla_hadoop_1_latest.selinux-permissive.qcow2 -o ! -f ${image_type}_sahara_vanilla_hadoop_2_latest.selinux-permissive.qcow2 ]; then
       echo "Images aren't built"
       exit 1
     fi
     mv ${image_type}_sahara_vanilla_hadoop_1_latest.selinux-permissive.qcow2 ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1.qcow2
     mv ${image_type}_sahara_vanilla_hadoop_2_latest.selinux-permissive.qcow2 ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2.qcow2
fi


glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1
glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2

case "$image_type" in
        ubuntu)
            SSH_USERNAME=ubuntu
            glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1 --file ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
            glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2 --file ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.3.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
            ;;

        fedora)
            SSH_USERNAME=fedora
            glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1 --file ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='fedora'
            glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2 --file ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.3.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='fedora'
            ;;

        centos)
            SSH_USERNAME=cloud-user
            glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1 --file ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='cloud-user'
            glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2 --file ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.3.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='cloud-user'
            ;;
esac

TIMEOUT=60

#False value for this variables means that tests are enabled
CINDER_TEST=True
CLUSTER_CONFIG_TEST=True
EDP_TEST=False
MAP_REDUCE_TEST=False
SWIFT_TEST=True
SCALING_TEST=True
TRANSIENT_TEST=True
VANILLA_IMAGE=ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1
VANILLA_TWO_IMAGE=ci-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2

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

mysql -usavanna-citest -psavanna-citest -Bse "DROP DATABASE IF EXISTS savanna"
mysql -usavanna-citest -psavanna-citest -Bse "create database savanna"

BUILD_ID=dontKill

#sudo pip install tox
mkdir /tmp/cache

export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

git clone https://review.openstack.org/openstack/sahara
cd sahara
sudo pip install .

echo "[DEFAULT]
" >> etc/sahara/sahara.conf

echo "infrastructure_engine=direct
" >> etc/sahara/sahara.conf

echo "
os_auth_host=172.18.168.42
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_identity_api_v3=true
use_neutron=true
[database]
connection=mysql://savanna-citest:savanna-citest@localhost/savanna?charset=utf8" >> etc/sahara/sahara.conf

echo "----------- sahara.conf -----------"
cat etc/sahara/sahara.conf
echo "----------- end of sahara.conf -----------"

#touch ~/.pip/pip.conf

#echo "
#[global]
#timeout = 60
#index-url = http://savanna-ci.vm.mirantis.net/pypi/savanna/
#extra-index-url = https://pypi.python.org/simple/
#download-cache = /home/ubuntu/.pip/cache/
#[install]
#use-mirrors = true
#find-links = http://savanna-ci.vm.mirantis.net:8181/simple/
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
OS_TENANT_ID = '$CI_TENANT_ID'
OS_AUTH_URL = 'http://172.18.168.42:5000/v2.0'
SAVANNA_HOST = '$ADDR'
FLAVOR_ID = '20'
CLUSTER_CREATION_TIMEOUT = $TIMEOUT
CLUSTER_NAME = 'img-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET'
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
SKIP_CINDER_TEST = '$CINDER_TEST'
SKIP_CLUSTER_CONFIG_TEST = $CLUSTER_CONFIG_TEST
SKIP_EDP_TEST = $EDP_TEST
SKIP_MAP_REDUCE_TEST = $MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SWIFT_TEST
SKIP_SCALING_TEST = $SCALING_TEST
SKIP_TRANSIENT_CLUSTER_TEST = $TRANSIENT_TEST
$VANILLA_PARAMS
" >> sahara/tests/integration/configs/itest.conf

echo "[VANILLA_TWO]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$VANILLA_TWO_IMAGE'
SKIP_CINDER_TEST = '$CINDER_TEST'
SKIP_MAP_REDUCE_TEST = $MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SWIFT_TEST
SKIP_SCALING_TEST = $SCALING_TEST
$VANILLA_PARAMS
" >> sahara/tests/integration/configs/itest.conf

echo "[HDP]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
SKIP_CINDER_TEST = '$CINDER_TEST'
SKIP_EDP_TEST = $EDP_TEST
SKIP_MAP_REDUCE_TEST = $MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SWIFT_TEST
SKIP_SCALING_TEST = $SCALING_TEST
$HDP_PARAMS
" >> sahara/tests/integration/configs/itest.conf

echo "[IDH]
IMAGE_NAME = '$IDH_IMAGE'
IDH_REPO_URL = 'file:///var/repo/intel'
OS_REPO_URL = 'http://172.18.87.221/mirror/centos/base/'
SSH_USERNAME = 'cloud-user'
MANAGER_FLAVOR_ID = '3'
" >> sahara/tests/integration/configs/itest.conf

touch $TMP_LOG
i=0

while true
do
        let "i=$i+1"
        diff $TOX_LOG $TMP_LOG >> $LOG_FILE
        cp -f $TOX_LOG $TMP_LOG
        if [ "$i" -gt "120" ]; then
                cat $LOG_FILE
                echo "project does not start" && FAILURE=1 && break
        fi
        if [ ! -f /tmp/sahara/log.txt ]; then
                sleep 10
        else
                echo "project is started" && FAILURE=0 && break
        fi
done

if [ "$FAILURE" = 0 ]; then

    export PYTHONUNBUFFERED=1

    cd /tmp/sahara
    tox -e integration -- vanilla --concurrency=1
    STATUS=`echo $?`
fi

echo "-----------Python integration env-----------"
cd /tmp/sahara && .tox/integration/bin/pip freeze

screen -S sahara-all -X quit

echo "-----------Python sahara env-----------"
cd /tmp/sahara && .tox/venv/bin/pip freeze

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
    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete $VANILLA_IMAGE
    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete $VANILLA_TWO_IMAGE
    exit 1
fi

if [ "$ZUUL_PIPELINE" == "check" ]
then
    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete $VANILLA_IMAGE
    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete $VANILLA_TWO_IMAGE
else
    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete ${image_type}_sahara_vanilla_hadoop_1_latest
    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-update $VANILLA_IMAGE --name ${image_type}_sahara_vanilla_hadoop_1_latest

    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete ${image_type}_sahara_vanilla_hadoop_2_latest
    glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-update $VANILLA_TWO_IMAGE --name ${image_type}_sahara_vanilla_hadoop_2_latest
fi
