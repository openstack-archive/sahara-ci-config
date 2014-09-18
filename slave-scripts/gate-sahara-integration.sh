#!/bin/bash

#this is to fix bug with testtools==0.9.35
#sed 's/testtools>=0.9.32/testtools==0.9.34/' -i test-requirements.txt

. $FUNCTION_PATH

check_openstack_host

sudo pip install .

WORKSPACE=${1:-$WORKSPACE}
JOB_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

hadoop_version=1
SKIP_CINDER_TEST=False
SKIP_CLUSTER_CONFIG_TEST=False
SKIP_EDP_TEST=False
SKIP_MAP_REDUCE_TEST=True
SKIP_SWIFT_TEST=True
SKIP_SCALING_TEST=False
SKIP_TRANSIENT_TEST=True
SKIP_ONLY_TRANSIENT_TEST=False
HDP_IMAGE=sahara-itests-ci-hdp-image-jdk-iptables-off
HDP_TWO_IMAGE=centos-6_4-64-hdp-2-0-hw
VANILLA_IMAGE=sahara-itests-ci-vanilla-image
VANILLA_TWO_IMAGE=ubuntu-vanilla-2.4-latest
SPARK_IMAGE=sahara_spark_latest
HEAT_JOB=False

if [[ $JOB_TYPE =~ heat ]]
then
    HEAT_JOB=True
    echo "Heat detected"
    JOB_TYPE=$(echo $JOB_TYPE | awk -F '_' '{ print $2 }')
    SKIP_TRANSIENT_TEST=True
fi
if [ $JOB_TYPE == 'hdp1' ]
then
   echo "HDP1 detected"
   PLUGIN_TYPE=hdp1
fi
if [ $JOB_TYPE == 'hdp2' ]
then
   hadoop_version=2
   PLUGIN_TYPE=hdp2
   echo "HDP2 detected"
fi
if [ $JOB_TYPE == 'vanilla' ]
then
   hadoop_version=$(echo $JOB_NAME | awk -F '-' '{ print $5}')
   if [ "$hadoop_version" == "1" ]; then
       PLUGIN_TYPE=vanilla1
       echo "Vanilla detected"
   else
       PLUGIN_TYPE=vanilla2
       if [ "$hadoop_version" == "2.3" ]; then
          VANILLA_TWO_IMAGE=ubuntu-vanilla-2.3-latest
          hadoop_version=2-3
          [ "$ZUUL_BRANCH" != "stable/icehouse" ] && echo "Vanilla 2.3 plugin is deprecated" && exit 0
       else
          HEAT_JOB=True
          hadoop_version=2-4
          [ "$ZUUL_BRANCH" == "stable/icehouse" ] && echo "Vanilla 2.4 plugin is not supported in stable/icehouse" && exit 0
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
   TRANSIENT_JOB=True
   [ "$HEAT_JOB" == "True" ] && [ "$ZUUL_BRANCH" == "stable/icehouse" ] && echo "Heat_Transient plugin is not supported in stable/icehouse" && exit 0
   echo "Transient detected"
fi
if [ $JOB_TYPE == 'cdh' ]
then
   os_version=$(echo $JOB_NAME | awk -F '-' '{ print $5}')
   if [ "$os_version" == "centos" ]; then
      CDH_IMAGE=centos_cdh_latest
      hadoop_version=2c
   else
      # temporary using native ubuntu image
      #CDH_IMAGE=ubuntu_cdh_latest
      CDH_IMAGE=ubuntu-12.04
      hadoop_version=2u
   fi
   PLUGIN_TYPE=cdh
   [ "$ZUUL_BRANCH" == "stable/icehouse" ] && echo "CDH plugin is not supported in stable/icehouse" && exit 0
   echo "CDH detected"
fi
if [ $JOB_TYPE == 'spark' ]
then
   PLUGIN_TYPE=spark
   SKIP_EDP_TEST=False
   SKIP_SCALING_TEST=False
   hadoop_version=1
   [ "$ZUUL_BRANCH" == "stable/icehouse" ] && echo "Spark plugin is not supported in stable/icehouse" && exit 0
   echo "Spark detected"
fi

cd $WORKSPACE
[ "$ZUUL_BRANCH" == "stable/icehouse" ] && git checkout stable/icehouse && sudo pip install -U -r requirements.txt

TOX_LOG=$WORKSPACE/.tox/venv/log/venv-1.log

create_database
#enable_pypi

write_sahara_main_conf etc/sahara/sahara.conf
start_sahara etc/sahara/sahara.conf

cd $WORKSPACE

CLUSTER_NAME="$HOST-$hadoop_version-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET"
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
