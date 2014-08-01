#!/bin/bash

#this is to fix bug with testtools==0.9.35
#sed 's/testtools>=0.9.32/testtools==0.9.34/' -i test-requirements.txt

. ./common-scripts.sh

check_openstack_host

sudo pip install .

WORKSPACE=${1:-$WORKSPACE}
JOB_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

HADOOP_VERSION=1
SKIP_CINDER_TEST=False
SKIP_CLUSTER_CONFIG_TEST=False
SKIP_EDP_TEST=False
SKIP_MAP_REDUCE_TEST=False
SKIP_SWIFT_TEST=False
SKIP_SCALING_TEST=False
SKIP_TRANSIENT_TEST=True
SKIP_ONLY_TRANSIENT_TEST=False
HDP_IMAGE=sahara-itests-ci-hdp-image-jdk-iptables-off
HDP_TWO_IMAGE=centos-6_4-64-hdp-2-0-hw
VANILLA_IMAGE=sahara-itests-ci-vanilla-image
CDH_IMAGE=ubuntu_cdh_latest
HEAT_JOB=False

if [[ $JOB_TYPE =~ heat ]]
then
    HEAT_JOB=True
    SSH_USERNAME=ec2-user
    echo "Heat detected"
    JOB_TYPE=$(echo $JOB_TYPE | awk -F '_' '{ print $2 }')
    SKIP_TRANSIENT_TEST=True
fi
if [ $JOB_TYPE == 'hdp1' ]
then
   echo "HDP1 detected"
   PLUGIN_TYPE=hdp1
   SSH_USERNAME=root
fi
if [ $JOB_TYPE == 'hdp2' ]
then
   SSH_USERNAME=root
   HADOOP_VERSION=2
   PLUGIN_TYPE=hdp2
   echo "HDP2 detected"
fi
if [ $JOB_TYPE == 'vanilla' ]
then
   HADOOP_VERSION=$(echo $JOB_NAME | awk -F '-' '{ print $5}')
   if [ "$HADOOP_VERSION" == "1" ]; then
       PLUGIN_TYPE=vanilla1 
       echo "Vanilla detected"
   else
       PLUGIN_TYPE=vanilla2
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
   PLUGIN_TYPE=transient
   SKIP_EDP_TEST=False
   SKIP_TRANSIENT_TEST=False
   SKIP_ONLY_TRANSIENT_TEST=True
   SKIP_TRANSIENT_JOB=True
   echo "Transient detected"
fi
if [ $JOB_TYPE == 'cdh' ]
then
   PLUGIN_TYPE=cdh
   SSH_USERNAME=ubuntu
   echo "CDH detected"
fi

cd $WORKSPACE

TOX_LOG=$WORKSPACE/.tox/venv/log/venv-1.log

create_database
#enable_pypi

write_sahara_main_conf etc/sahara/sahara.conf
start_sahara etc/sahara/sahara.conf

cd $WORKSPACE

CLUSTER_NAME="$HOST-$HADOOP_VERSION-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET"
write_tests_conf $WORKSPACE/sahara/tests/integration/configs/itest.conf

run_tests

cat_logs $WORKSPACE

if [ "$FAILURE" != 0 ]; then
    exit 1
fi

if [[ "$STATUS" != 0 ]]
then
    exit 1
fi
