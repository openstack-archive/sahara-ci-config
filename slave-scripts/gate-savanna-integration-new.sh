#!/bin/bash

#this is to fix bug with testtools==0.9.35
#sed 's/testtools>=0.9.32/testtools==0.9.34/' -i test-requirements.txt

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

sudo pip install .

WORKSPACE=${1:-$WORKSPACE}

export PIP_USE_MIRRORS=True

JOB_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')
TIMEOUT=60
if [ "$ZUUL_BRANCH" == "stable/icehouse" ]
then
   SAHARA_BIN=sahara-api
else
   SAHARA_BIN=sahara-all
fi

HADOOP_VERSION=1
#False value for this variables means that tests are enabled
CINDER_TEST=False
CLUSTER_CONFIG_TEST=False
EDP_TEST=False
MAP_REDUCE_TEST=False
SWIFT_TEST=False
SCALING_TEST=False
TRANSIENT_TEST=True
ONLY_TRANSIENT_TEST=False
HDP1_IMAGE=savanna-itests-ci-hdp-image-jdk-iptables-off
HDP2_IMAGE=centos-6_4-64-hdp-2-0-hw
VANILLA_IMAGE=savanna-itests-ci-vanilla-image
CDH_IMAGE=ubuntu_cdh_latest
HEAT_JOB=False

if [ $JOB_TYPE == 'heat_vanilla' ]
then
    HEAT_JOB=True
    SSH_USERNAME=ec2-user
    echo "Heat detected"
    JOB_TYPE=$(echo $JOB_TYPE | awk -F '_' '{ print $2 }')
    CINDER_TEST=True
    TRANSIENT_TEST=True
fi

if [ $JOB_TYPE == 'hdp1' ]
then
   HDP1_JOB=True
   echo "HDP1 detected"
fi

if [ $JOB_TYPE == 'hdp2' ]
then
   HDP2_JOB=True
   SSH_USERNAME=root
   HADOOP_VERSION=2
   echo "HDP2 detected"
fi

if [ $JOB_TYPE == 'vanilla' ]
then
   HADOOP_VERSION=$(echo $JOB_NAME | awk -F '-' '{ print $5}')
   if [ "$HADOOP_VERSION" == "1" ]; then
       VANILLA_JOB=True
       VANILLA_IMAGE=savanna-itests-ci-vanilla-image
       echo "Vanilla detected"
   else
       VANILLA2_JOB=True
       if [ "$HADOOP_VERSION" == "2.3" ]; then
          VANILLA_TWO_IMAGE=ubuntu-vanilla-2.3-latest
          HADOOP_VERSION=2-3
       else
          VANILLA_TWO_IMAGE=ubuntu-vanilla-2.4-latest
          HADOOP_VERSION=2-4
       fi
       echo "Vanilla2 detected"
   fi
fi
if [ $JOB_TYPE == 'transient' ]
then
   EDP_TEST=False
   TRANSIENT_TEST=False
   ONLY_TRANSIENT_TEST=True
   HEAT_JOB=False
   TRANSIENT_JOB=True

   echo "Transient detected"
fi
if [ $JOB_TYPE == 'cdh' ]
then
   CDH_JOB=True
   SSH_USERNAME=ubuntu
   echo "CDH detected"
fi

export PYTHONUNBUFFERED=1

cd $WORKSPACE

TOX_LOG=$WORKSPACE/.tox/venv/log/venv-1.log
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

echo "[DEFAULT]
" >> etc/sahara/sahara.conf

if [ "$HEAT_JOB" = True ]
then
    echo "infrastructure_engine=heat
    " >> etc/sahara/sahara.conf
else
    echo "infrastructure_engine=direct
    " >> etc/sahara/sahara.conf
fi

if [ "$CDH_JOB" ]
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
min_transient_cluster_active_time=30
node_domain = nl
[database]
connection=mysql://savanna-citest:savanna-citest@localhost/savanna?charset=utf8
[keystone_authtoken]
auth_uri=http://$OPENSTACK_HOST:5000/v2.0/
identity_uri=http://$OPENSTACK_HOST:35357/
admin_user=ci-user
admin_password=nova
admin_tenant_name=ci
" >> etc/sahara/sahara.conf

echo "----------- sahara.conf -----------"
cat etc/sahara/sahara.conf
echo "----------- end of sahara.conf -----------"

#touch ~/.pip/pip.conf

#echo "
#[global]
#timeout = 60
#index-url = https://sahara.mirantis.com/pypi/
#extra-index-url = http://pypi.openstack.org/openstack/
#download-cache = /home/jenkins/.pip/cache/
#[install]
#use-mirrors = true
#" > ~/.pip/pip.conf

#echo "
#[easy_install]
#index_url = https://sahara.mirantis.com/pypi/
#" > ~/.pydistutils.cfg

sahara-db-manage --config-file etc/sahara/sahara.conf upgrade head
STATUS=`echo $?`
if [[ "$STATUS" != 0 ]]
then
    exit 1
fi

screen -dmS sahara-all /bin/bash -c "PYTHONUNBUFFERED=1 $SAHARA_BIN --config-file etc/sahara/sahara.conf -d --log-file log.txt | tee /tmp/tox-log.txt"


export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

echo "[COMMON]
OS_USERNAME = 'ci-user'
OS_PASSWORD = 'nova'
OS_TENANT_NAME = 'ci'
OS_TENANT_ID = '$TENANT_ID'
OS_AUTH_URL = 'http://$OPENSTACK_HOST:5000/v2.0'
SAVANNA_HOST = '$ADDR'
FLAVOR_ID = '20'
CLUSTER_CREATION_TIMEOUT = $TIMEOUT
CLUSTER_NAME = '$HOST-$HADOOP_VERSION-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET'
FLOATING_IP_POOL = 'public'
NEUTRON_ENABLED = True
INTERNAL_NEUTRON_NETWORK = 'private'
JOB_LAUNCH_TIMEOUT = 15
HDFS_INITIALIZATION_TIMEOUT = 10
$COMMON_PARAMS
" >> $WORKSPACE/sahara/tests/integration/configs/itest.conf

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
ONLY_TRANSIENT_CLUSTER_TEST = $ONLY_TRANSIENT_TEST
$VANILLA_PARAMS
" >> $WORKSPACE/sahara/tests/integration/configs/itest.conf

echo "[VANILLA_TWO]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$VANILLA_TWO_IMAGE'
SKIP_CINDER_TEST = '$CINDER_TEST'
SKIP_MAP_REDUCE_TEST = $MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SWIFT_TEST
SKIP_SCALING_TEST = $SCALING_TEST
$VANILLA_PARAMS
" >> $WORKSPACE/sahara/tests/integration/configs/itest.conf

if [ "$JOB_TYPE" == "vanilla" -a "$HADOOP_VERSION" == "2-4" ]; then
   echo "HADOOP_VERSION = '2.4.1'
HADOOP_EXAMPLES_JAR_PATH = '/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.4.1.jar'
SKIP_EDP_JOB_TYPES = Pig
" >> sahara/tests/integration/configs/itest.conf
fi

echo "[HDP]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP1_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
SKIP_CINDER_TEST = '$CINDER_TEST'
SKIP_EDP_TEST = $EDP_TEST
SKIP_MAP_REDUCE_TEST = $MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SWIFT_TEST
SKIP_SCALING_TEST = $SCALING_TEST
$HDP1_PARAMS
" >> $WORKSPACE/sahara/tests/integration/configs/itest.conf

echo "[HDP2]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP2_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
" >> $WORKSPACE/sahara/tests/integration/configs/itest.conf

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

    echo "project is started"
    export PYTHONUNBUFFERED=1

    cd $WORKSPACE
    if [ $HDP1_JOB ]
    then
        if [ "$ZUUL_BRANCH" == "stable/icehouse" ]
        then
            tox -e integration -- hdp --concurrency=1
            STATUS=`echo $?`
        else
            tox -e integration -- hdp1 --concurrency=1
            STATUS=`echo $?`
        fi
    fi

    if [ $HDP2_JOB ]
    then
        tox -e integration -- hdp2 --concurrency=1
        STATUS=`echo $?`
    fi

    if [ $VANILLA_JOB ]
    then
        tox -e integration -- vanilla1 --concurrency=1
        STATUS=`echo $?`
    fi

    if [ $VANILLA2_JOB ]
    then
        tox -e integration -- vanilla2 --concurrency=1
        STATUS=`echo $?`
    fi

    if [ $TRANSIENT_JOB ]
    then
        tox -e integration -- transient --concurrency=1
        STATUS=`echo $?`
    fi

    if [ $CDH_JOB ]
    then
        tox -e integration -- cdh --concurrency=1
        STATUS=`echo $?`
    fi

fi

echo "-----------Python integration env-----------"
cd $WORKSPACE && .tox/integration/bin/pip freeze

screen -S sahara-all -X quit

echo "-----------Python sahara env-----------"
pip freeze

echo "-----------Sahara Log------------"
cat $WORKSPACE/log.txt
rm -rf /tmp/workspace/
rm -rf /tmp/cache/

echo "-----------Tox log-----------"
cat /tmp/tox-log.txt
rm -f /tmp/tox-log.txt

rm $TMP_LOG
rm -f $LOG_FILE

if [ "$FAILURE" != 0 ]; then
    exit 1
fi

if [[ "$STATUS" != 0 ]]
then
    exit 1
fi
