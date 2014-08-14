#!/bin/bash

TMP_LOG=/tmp/tox.log
LOG_FILE=/tmp/tox_log.txt
BUILD_ID=dontKill
TIMEOUT=60
export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

# This function determines Openstack host by checking internal address (second octet)
check_openstack_host() {
  NETWORK=`ifconfig eth0 | awk -F ' *|:' '/inet addr/{print $4}' | awk -F . '{print $2}'`
  if [ "$NETWORK" == "0" ]; then
      export OPENSTACK_HOST="172.18.168.42"
      export HOST="c1"
      export TENANT_ID="$CI_LAB_TENANT_ID"
  else
      export OPENSTACK_HOST="172.18.168.43"
      export HOST="c2"
      export TENANT_ID="$STACK_SAHARA_TENANT_ID"
  fi
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
}

write_sahara_main_conf() {
  conf_path=$1
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
    echo "plugins=vanilla,hdp,cdh
" >> $conf_path
  fi
  echo "os_auth_host=$OPENSTACK_HOST
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_identity_api_v3=true
use_neutron=true
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
  screen -dmS $sahara_bin /bin/bash -c "PYTHONUNBUFFERED=1 $sahara_bin --config-file $conf_path -d --log-file log.txt"

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
FLAVOR_ID = '20'
CLUSTER_CREATION_TIMEOUT = $TIMEOUT
CLUSTER_NAME = '$CLUSTER_NAME'
FLOATING_IP_POOL = 'public'
NEUTRON_ENABLED = True
INTERNAL_NEUTRON_NETWORK = 'private'
JOB_LAUNCH_TIMEOUT = 15
HDFS_INITIALIZATION_TIMEOUT = 10
" >> $test_conf_path

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
ONLY_TRANSIENT_CLUSTER_TEST = $SKIP_ONLY_TRANSIENT_TEST
" >> $test_conf_path

  echo "[VANILLA_TWO]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$VANILLA_TWO_IMAGE'
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
" >> $test_conf_path

if [ $PLUGIN_TYPE == "vanilla2" -a "$hadoop_version" == "2-4" ]; then
     echo "HADOOP_VERSION = '2.4.1'
SKIP_EDP_JOB_TYPES = Pig
HADOOP_EXAMPLES_JAR_PATH = '/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.4.1.jar'
" >> $test_conf_path
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
" >> $test_conf_path

  echo "[HDP2]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP_TWO_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
" >> $test_conf_path

  echo "[CDH]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$CDH_IMAGE'
" >>  $test_conf_path

  echo "[SPARK]
IMAGE_NAME = '$SPARK_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
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
           tox -e integration -- transient --concurrency=1
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

  echo "-----------Sahara Log------------"
  cat $log_path/log.txt
}
