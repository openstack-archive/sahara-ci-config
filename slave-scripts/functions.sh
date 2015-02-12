#!/bin/bash

TMP_LOG=/tmp/tox.log
LOG_FILE=/tmp/tox_log.txt
BUILD_ID=dontKill
TIMEOUT=60
export ADDR=$(ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}')

# This function determines Openstack host by checking internal address (second octet)
check_openstack_host() {
  NETWORK=$(ifconfig eth0 | awk -F ' *|:' '/inet addr/{print $4}' | awk -F . '{print $2}')
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
  mkdir logs
  if [ "$ZUUL_BRANCH" == "stable/icehouse" ]
  then
     sahara_bin=sahara-api
  else
     sahara_bin=sahara-all
  fi
  sahara-db-manage --config-file $conf_path  upgrade head
  status=$?
  if [[ "$status" != 0 ]]
  then
     echo "Command 'sahara-db-manage' failed"
     exit 1
  fi
  if [ "$ZUUL_BRANCH" == "master" -a \( "$PLUGIN_TYPE" == "vanilla2" -a "$hadoop_version" == "2-6" -o "$PLUGIN_TYPE" == "hdp2" -o "$PLUGIN_TYPE" == " transient" \) -o "$hadoop_version" == "2-4" ]; then
    screen -dmS sahara-api /bin/bash -c "PYTHONUNBUFFERED=1 sahara-api --config-dir $conf_dir -d --log-file logs/sahara-log-api.txt"
    sleep 2
    screen -dmS sahara-engine_1 /bin/bash -c "PYTHONUNBUFFERED=1 sahara-engine --config-dir $conf_dir -d --log-file logs/sahara-log-engine-1.txt"
    screen -dmS sahara-engine_2 /bin/bash -c "PYTHONUNBUFFERED=1 sahara-engine --config-dir $conf_dir -d --log-file logs/sahara-log-engine-2.txt"
  else
    screen -dmS $sahara_bin /bin/bash -c "PYTHONUNBUFFERED=1 $sahara_bin --config-dir $conf_dir -d --log-file logs/sahara-log.txt"
  fi

  api_responding_timeout=30
  FAILURE=0
  if ! timeout ${api_responding_timeout} sh -c "while ! curl -s http://127.0.0.1:8386/v1.1/ 2>/dev/null | grep -q 'Authentication required' ; do sleep 1; done"; then
    echo "Sahara API failed to respond within ${api_responding_timeout} seconds"
    FAILURE=1
  fi
}

insert_scenario_value() {
  value=$1
  sed -i "s/%${value}%/${!value}/g" $TESTS_CONFIG_FILE
}

write_tests_conf() {
  if [ "$JOB_NAME" =~ scenario ]; then
    case $PLUGIN_TYPE in
       vanilla2)
          IMAGE_NAME="$VANILLA_TWO_IMAGE"
       ;;
       spark)
          IMAGE_NAME="$SPARK_IMAGE"
       ;;
    esac
    insert_scenario_value OS_USERNAME
    insert_scenario_value OS_PASSWORD
    insert_scenario_value OS_TENANT_NAME
    insert_scenario_value OPENSTACK_HOST
    insert_scenario_value CLUSTER_NAME
    insert_scenario_value TENANT_ID
    insert_scenario_value IMAGE_NAME
  else
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
NEUTRON_ENABLED = $USE_NEUTRON
INTERNAL_NEUTRON_NETWORK = 'private'
JOB_LAUNCH_TIMEOUT = 15
HDFS_INITIALIZATION_TIMEOUT = 10

[VANILLA]
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

[VANILLA_TWO]
IMAGE_NAME = '$VANILLA_TWO_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_EDP_JOB_TYPES = $SKIP_EDP_JOB_TYPES
" >> $TESTS_CONFIG_FILE

if [ "$PLUGIN_TYPE" == "transient" ]; then
   if [ "$ZUUL_BRANCH" == "master" ]; then
     echo "HADOOP_VERSION = '2.6.0'
" >> $TESTS_CONFIG_FILE
   elif [[ "$ZUUL_BRANCH" =~ juno ]]; then
     echo "HADOOP_VERSION = '2.4.1'
" >> $TESTS_CONFIG_FILE
   fi
fi

if [ "$PLUGIN_TYPE" == "vanilla2" -a \( "$hadoop_version" == "2-4" -o "$hadoop_version" == "2-6" \) ]; then
   if [ "$hadoop_version" == "2-4" ]; then
      version="2.4.1"
   else
      version="2.6.0"
   fi
   echo "HADOOP_VERSION = '${version}'
HADOOP_EXAMPLES_JAR_PATH = '/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-${version}.jar'
" >> $TESTS_CONFIG_FILE
fi

  echo "[HDP]
IMAGE_NAME = '$HDP_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_CINDER_TEST = '$SKIP_CINDER_TEST'
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST

[HDP2]
IMAGE_NAME = '$HDP_TWO_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST

[CDH]
IMAGE_NAME = '$CDH_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_MAP_REDUCE_TEST = $SKIP_MAP_REDUCE_TEST
SKIP_SWIFT_TEST = $SKIP_SWIFT_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
SKIP_CINDER_TEST = $SKIP_CINDER_TEST
SKIP_EDP_TEST = $SKIP_EDP_TEST
CM_REPO_LIST_URL = 'http://$OPENSTACK_HOST/cdh-repo/cm.list'
CDH_REPO_LIST_URL = 'http://$OPENSTACK_HOST/cdh-repo/cdh.list'

[SPARK]
IMAGE_NAME = '$SPARK_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = $SKIP_ALL_TESTS_FOR_PLUGIN
SKIP_EDP_TEST = $SKIP_EDP_TEST
SKIP_SCALING_TEST = $SKIP_SCALING_TEST
" >> $TESTS_CONFIG_FILE
  fi
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
              STATUS=$?
           else
              tox -e integration -- hdp1 --concurrency=1
              STATUS=$?
           fi
           ;;
        hdp2)
           tox -e integration -- hdp2 --concurrency=1
           STATUS=$?
           ;;
        vanilla1)
           tox -e integration -- vanilla1 --concurrency=1
           STATUS=$?
           ;;
        vanilla2)
           if [ $ZUUL_BRANCH == "master" ]; then
              tox -e scenario $TESTS_CONFIG_FILE
              STATUS=$?
           else
              tox -e integration -- vanilla2 --concurrency=1
              STATUS=$?
           fi
           ;;
        transient)
           tox -e integration -- transient --concurrency=3
           STATUS=$?
           ;;
        cdh)
          tox -e integration -- cdh --concurrency=1
          STATUS=$?
          ;;
        spark)
          if [ $ZUUL_BRANCH == "master" ]; then
             tox -e scenario $TESTS_CONFIG_FILE
             STATUS=$?
          else
             tox -e integration -- spark --concurrency=1
             STATUS=$?
          fi
          ;;
     esac
  fi
}

print_python_env() {
  sahara_workspace=$1
  cd $sahara_workspace
  .tox/integration/bin/pip freeze > logs/python-integration-env.txt
  pip freeze > logs/python-system-env.txt
}
