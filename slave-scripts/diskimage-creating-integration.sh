#!/bin/bash

check_error_code() {
   if [ "$1" != "0" ]; then
       echo "$2 image $3 doesn't build"
       exit 1
   fi
}

register_vanilla_image() {
   # 1 - hadoop version, 2 - username, 3 - image name
   case "$1" in
           1)
             glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
           2)
             glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.3.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'="${2}"
             ;;
   esac
}

register_hdp_image() {
   # 1 - hadoop version, 2 - username, 3 - image name
   case "$1" in
           1)
             glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.3.2'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'="${2}"
             ;;
           2)
             glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-create --name $3 --file $3.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.0.6'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'="${2}"
             ;;
   esac
}

delete_image() {
   glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-delete $1
}

upload_image() {
   # 1 - plugin, 2 - username, 3 - image name
   delete_image $3

   case "$1" in
           vanilla-1)
             register_vanilla_image "1" "$2" "$3"
           ;;
           vanilla-2)
             register_vanilla_image "2" "$2" "$3"
           ;;
           hdp1)
             register_hdp_image "1" "$2" "$3"
           ;;
           hdp2)
             register_hdp_image "2" "$2" "$3"
           ;;
   esac
}

rename_image() {
   # 1 - source image, 2 - target image
   glance --os-username ci-user --os-auth-url http://172.18.168.42:5000/v2.0/ --os-tenant-name ci --os-password nova image-update $1 --name $2
}

plugin="$1"
image_type=${2:-ubuntu}
TIMEOUT=60
GERRIT_CHANGE_NUMBER=$ZUUL_CHANGE
#False value for this variables means that tests are enabled
CINDER_TEST=True
CLUSTER_CONFIG_TEST=True
EDP_TEST=False
MAP_REDUCE_TEST=False
SWIFT_TEST=True
SCALING_TEST=True
TRANSIENT_TEST=True
VANILLA_IMAGE=ci-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_1
VANILLA_TWO_IMAGE=ci-sahara-vanilla-${image_type}-${GERRIT_CHANGE_NUMBER}-hadoop_2
HDP_IMAGE=ci-sahara-hdp-centos-${GERRIT_CHANGE_NUMBER}-hadoop_1
HDP_TWO_IMAGE=ci-sahara-hdp-centos-${GERRIT_CHANGE_NUMBER}-hadoop_2
SPARK_IMAGE=ci-sahara-spark-ubuntu-${GERRIT_CHANGE_NUMBER}
SSH_USERNAME="ubuntu"

case $plugin in
    vanilla)
    sudo SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 1
    check_error_code $? "vanilla-1" ${image_type}
    mv ${image_type}_sahara_vanilla_hadoop_1_latest*.qcow2 ${VANILLA_IMAGE}.qcow2

    sudo SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p vanilla -i $image_type -v 2
    check_error_code $? "vanilla-2" ${image_type}
    mv ${image_type}_sahara_vanilla_hadoop_2_latest*.qcow2 ${VANILLA_TWO_IMAGE}.qcow2

    if [ "${image_type}" == 'centos' ]; then
        username='cloud-user'
    else
        username=${image_type}
    fi
    SSH_USERNAME=${username}
    upload_image "vanilla-1" "${username}" ${VANILLA_IMAGE}
    upload_image "vanilla-2" "${username}" ${VANILLA_TWO_IMAGE}
    ;;

    spark)
    sudo SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p "spark"
    image_type="ubuntu"
    check_error_code $? "spark" "ubuntu"
    mv ubuntu_sahara_spark_latest.qcow2 ${SPARK_IMAGE}.qcow2
    exit $?
    ;;

    hdp1)
    sudo SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p hdp -v 1
    image_type="centos"
    check_error_code $? "hdp1" "centos"
    mv centos-6_4-64-hdp-1-3.qcow2 ${HDP_IMAGE}.qcow2
    SSH_USERNAME="root"
    upload_image "hdp1" "root" ${HDP_IMAGE}
    ;;

    hdp2)
    sudo SIM_REPO_PATH=$WORKSPACE bash diskimage-create/diskimage-create.sh -p hdp -v 2
    image_type="centos"
    check_error_code $? "hdp2" "centos"
    mv centos-6_4-64-hdp-2-0.qcow2 ${HDP_TWO_IMAGE}.qcow2
    SSH_USERNAME="root"
    upload_image "hdp2" "root" ${HDP_TWO_IMAGE}
    ;;
esac

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
connection=mysql://savanna-citest:savanna-citest@localhost/savanna?charset=utf8
[keystone_authtoken]
auth_uri=http://172.18.168.42:5000/v2.0/
identity_uri=http://172.18.168.42:35357/
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
CLUSTER_NAME = '$image_type-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET'
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

echo "[HDP2]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP_TWO_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
SKIP_SCALING_TEST = $SCALING_TEST
" >> $WORKSPACE/sahara/tests/integration/configs/itest.conf

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
    if [ "${plugin}" == "vanilla" ]; then
        tox -e integration -- vanilla --concurrency=1
        STATUS=`echo $?`
    fi
    if [ "${plugin}" == "hdp1" ]; then
        tox -e integration -- hdp1 --concurrency=1
        STATUS=`echo $?`
    fi
    if [ "${plugin}" == "hdp2" ]; then
        tox -e integration -- hdp2 --concurrency=1
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
        delete_image $VANILLA_IMAGE
        delete_image $VANILLA_TWO_IMAGE
    fi
    if [ "${plugin}" == "hdp1" ]; then
        delete_image $HDP_IMAGE
    fi
    if [ "${plugin}" == "hdp2" ]; then
        delete_image $HDP_TWO_IMAGE
    fi
    exit 1
fi

if [ "$ZUUL_PIPELINE" == "check" ]
then
    if [ "${plugin}" == "vanilla" ]; then
        delete_image $VANILLA_IMAGE
        delete_image $VANILLA_TWO_IMAGE
    fi
    if [ "${plugin}" == "hdp1" ]; then
        delete_image $HDP_IMAGE
    fi
    if [ "${plugin}" == "hdp2" ]; then
        delete_image $HDP_TWO_IMAGE
    fi
else
    if [ "${plugin}" == "vanilla" ]; then
        delete_image ${image_type}_sahara_vanilla_hadoop_1_latest
        rename_image $VANILLA_IMAGE ${image_type}_sahara_vanilla_hadoop_1_latest
        delete_image ${image_type}_sahara_vanilla_hadoop_2_latest
        rename_image $VANILLA_TWO_IMAGE ${image_type}_sahara_vanilla_hadoop_2_latest
    fi
    if [ "${plugin}" == "hdp1" ]; then
        delete_image centos_sahara_hdp_hadoop_1_latest
        rename_image $HDP_IMAGE centos_sahara_hdp_hadoop_1_latest
    fi
    if [ "${plugin}" == "hdp2" ]; then
        delete_image centos_sahara_hdp_hadoop_2_latest
        rename_image $HDP_TWO_IMAGE centos_sahara_hdp_hadoop_2_latest
    fi
fi
