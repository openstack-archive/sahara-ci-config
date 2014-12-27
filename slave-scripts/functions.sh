#!/bin/bash

TMP_LOG=/tmp/tox.log
LOG_FILE=/tmp/tox_log.txt
BUILD_ID=dontKill
TIMEOUT=60
export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

# This function determines Openstack host by checking internal address (second octet)
check_openstack_host() {
  NETWORK=`ifconfig eth0 | awk -F ' *|:' '/inet addr/{print $4}' | awk -F . '{print $2}'`
  export OS_USERNAME=ci-user
  export OS_TENANT_NAME=ci
  export OS_PASSWORD=nova
  if [ "$NETWORK" == "0" ]; then
      export OPENSTACK_HOST="172.18.168.42"
      export HOST="c1"
      export TENANT_ID="$CI_LAB_TENANT_ID"
      export USE_NEUTRON=true
  else
      export OPENSTACK_HOST="172.18.168.43"
      export HOST="c2"
      export TENANT_ID="$STACK_SAHARA_TENANT_ID"
      export USE_NEUTRON=false
  fi
  export OS_AUTH_URL=http://$OPENSTACK_HOST:5000/v2.0/
}

create_database() {
  mysql -usahara-citest -psahara-citest -Bse "DROP DATABASE IF EXISTS sahara"
  mysql -usahara-citest -psahara-citest -Bse "create database sahara"
}

enable_pypi() {
  mkdir ~/.pip
  export PIP_USE_MIRRORS=True
  echo "
[global]
timeout = 60
index-url = http://172.18.168.44/simple/
extra-index-url = https://pypi.python.org/simple/
download-cache = /home/jenkins/.pip/cache/
[install]
use-mirrors = true
" > ~/.pip/pip.conf
  echo "
[easy_install]
index_url = http://172.18.168.44/simple/
" > ~/.pydistutils.cfg
}

write_sahara_main_conf() {
  conf_path=$1
  HEAT_JOB=False
  echo "[DEFAULT]
" >> $conf_path
  if [ "$HEAT_JOB" == "True" ]
  then
    echo "infrastructure_engine=heat
" >> $conf_path
  else
    echo "infrastructure_engine=direct
" >> $conf_path
  fi
  if [ "$PLUGIN_TYPE" == "cdh" ]
  then
    echo "plugins=cdh
" >> $conf_path
  elif [ "$PLUGIN_TYPE" == "spark" ]
  then
    echo "plugins=spark
" >> $conf_path
  elif [ "$TEMPEST" == "True" ]; then
    echo "plugins=fake
" >> $conf_path
  fi
  echo "os_auth_host=$OPENSTACK_HOST
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_identity_api_v3=true
use_neutron=$USE_NEUTRON
min_transient_cluster_active_time=30
node_domain = nl
[database]
connection=mysql://sahara-citest:sahara-citest@localhost/sahara?charset=utf8
[keystone_authtoken]
auth_uri=http://$OPENSTACK_HOST:5000/v2.0/
identity_uri=http://$OPENSTACK_HOST:35357/
admin_user=ci-user
admin_password=nova
admin_tenant_name=ci" >> $conf_path

  echo "----------- sahara.conf -----------"
  cat $conf_path
  echo "----------- end of sahara.conf -----------"
}

start_sahara() {
  conf_path=$1
  conf_dir=$(dirname $1)
  if [ "$ZUUL_BRANCH" == "stable/icehouse" ]
  then
     sahara_bin=sahara-api
  else
     sahara_bin=sahara-all
  fi
  sahara-db-manage --config-file $conf_path  upgrade head
  status=`echo $?`
  if [[ "$status" != 0 ]]
  then
     echo "Command 'sahara-db-manage' failed"
     exit 1
  fi
  if [ "$ZUUL_BRANCH" == "master" -a \( "$PLUGIN_TYPE" == "vanilla2" -a "$hadoop_version" == "2-4" -o "$PLUGIN_TYPE" == "hdp2" -o "$PLUGIN_TYPE" == " transient" \) ]; then
    screen -dmS sahara-api /bin/bash -c "PYTHONUNBUFFERED=1 sahara-api --config-dir $conf_dir -d --log-file log-api.txt"
    sleep 2
    screen -dmS sahara-engine_1 /bin/bash -c "PYTHONUNBUFFERED=1 sahara-engine --config-dir $conf_dir -d --log-file log-engine-1.txt"
    screen -dmS sahara-engine_2 /bin/bash -c "PYTHONUNBUFFERED=1 sahara-engine --config-dir $conf_dir -d --log-file log-engine-2.txt"
  else
    screen -dmS $sahara_bin /bin/bash -c "PYTHONUNBUFFERED=1 $sahara_bin --config-dir $conf_dir -d --log-file log.txt"
  fi

  api_responding_timeout=30
  FAILURE=0
  if ! timeout ${api_responding_timeout} sh -c "while ! curl -s http://127.0.0.1:8386/v1.1/ 2>/dev/null | grep -q 'Authentication required' ; do sleep 1; done"; then
    echo "Sahara API failed to respond within ${api_responding_timeout} seconds"
    FAILURE=1
  fi
}

write_tests_conf() {
  test_conf_path=$1

  echo "[COMMON]
OS_USERNAME = 'ci-user'
OS_PASSWORD = 'nova'
OS_TENANT_NAME = 'ci'
OS_TENANT_ID = '$TENANT_ID'
OS_AUTH_URL = 'http://$OPENSTACK_HOST:5000/v2.0'
SAHARA_HOST = '$ADDR'
FLAVOR_ID = '21'
CLUSTER_CREATION_TIMEOUT = $TIMEOUT
CLUSTER_NAME = '$CLUSTER_NAME'
FLOATING_IP_POOL = 'public'
NEUTRON_ENABLED = $USE_NEUTRON
INTERNAL_NEUTRON_NETWORK = 'private'
JOB_LAUNCH_TIMEOUT = 15
HDFS_INITIALIZATION_TIMEOUT = 10
" >> $test_conf_path

  echo "[VANILLA]
IMAGE_NAME = '$VANILLA_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_CLUSTER_CONFIG_TEST = $SKIP_CLUSTER_CONFIG_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_TRANSIENT_CLUSTER_TEST = $SKIP_TRANSIENT_TEST
ONLY_TRANSIENT_CLUSTER_TEST = $SKIP_ONLY_TRANSIENT_TEST
" >> $test_conf_path

  echo "[VANILLA_TWO]
IMAGE_NAME = '$VANILLA_TWO_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
" >> $test_conf_path

if [ "$PLUGIN_TYPE" == "transient" ]; then
     echo "HADOOP_VERSION = '2.4.1'
" >> $test_conf_path
fi

if [ "$PLUGIN_TYPE" == "vanilla2" -a \( "$hadoop_version" == "2-4" -o "$hadoop_version" == "2-6" \) ]; then
   if [ "$hadoop_version" == "2-4" ]; then
      version="2.4.1"
   else
      version="2.6.0"
   fi
   echo "HADOOP_VERSION = '${version}'
HADOOP_EXAMPLES_JAR_PATH = '/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-${version}.jar'
" >> $test_conf_path
fi

  echo "[HDP]
IMAGE_NAME = '$HDP_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
" >> $test_conf_path

  echo "[HDP2]
IMAGE_NAME = '$HDP_TWO_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
" >> $test_conf_path

  echo "[CDH]
IMAGE_NAME = '$CDH_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_CINDER_TEST = $SKIP_CINDER_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
CM_REPO_LIST_URL = 'http://$OPENSTACK_HOST/cdh-repo/cm.list'
CDH_REPO_LIST_URL = 'http://$OPENSTACK_HOST/cdh-repo/cdh.list'
" >>  $test_conf_path

  echo "[SPARK]
IMAGE_NAME = '$SPARK_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
" >> $test_conf_path
}

run_tests() {
  if [ "$FAILURE" = 0 ]; then
    echo "Integration tests are started"
    export PYTHONUNBUFFERED=1
    case $PLUGIN_TYPE in
        hdp1)
           if [ "$ZUUL_BRANCH" == "stable/icehouse" ]
           then
              tox -e integration -- hdp --concurrency=1
              STATUS=`echo $?`
           else
              tox -e integration -- hdp1 --concurrency=1
              STATUS=`echo $?`
           fi
           ;;
        hdp2)
           tox -e integration -- hdp2 --concurrency=1
           STATUS=`echo $?`
           ;;
        vanilla1)
           tox -e integration -- vanilla1 --concurrency=1
           STATUS=`echo $?`
           ;;
        vanilla2)
           tox -e integration -- vanilla2 --concurrency=1
           STATUS=`echo $?`
           ;;
        transient)
           tox -e integration -- transient --concurrency=3
           STATUS=`echo $?`
           ;;
        cdh)
          tox -e integration -- cdh --concurrency=1
          STATUS=`echo $?`
          ;;
        spark)
          tox -e integration -- spark --concurrency=1
          STATUS=`echo $?`
          ;;
     esac
  fi
}

cat_logs() {
  log_path=$1
  echo "-----------Python integration env-----------"
  cd $log_path && .tox/integration/bin/pip freeze

  echo "-----------Python sahara env-----------"
  cd $log_path && pip freeze

  if [ "$ZUUL_BRANCH" == "master" -a \( "$PLUGIN_TYPE" == "vanilla2" -a "$hadoop_version" == "2-4" -o "$PLUGIN_TYPE" == "hdp2" \) ]; then
     echo "-----------Sahara API Log------------"
     cat $log_path/log-api.txt
     echo "-------------------------------------"
     echo "-----------Sahara Engine Log---------"
     echo "-----------Engine-1 Log---------"
     cat $log_path/log-engine-1.txt
     echo "-------------------------------------"
     echo "-----------Engine-2 Log---------"
     cat $log_path/log-engine-2.txt
     echo "-------------------------------------"
  else
     echo "-----------Sahara Log------------"
     cat $log_path/log.txt
  fi
}
