#!/bin/bash -xe

sahara_templates_configs_path=$WORKSPACE/sahara-ci-config/config/sahara

enable_pypi() {
  mkdir -p ~/.pip
  export PIP_USE_MIRRORS=True
  cp $sahara_templates_configs_path/pip.conf ~/.pip/pip.conf
  cp $sahara_templates_configs_path/.pydistutils.cfg ~/.pydistutils.cfg
}

conf_has_option() {
  local file=$1
  local section=$2
  local option=$3
  local line

  line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
  [ -n "$line" ]
}

insert_config_value() {
  local file=$1
  local section=$2
  local option=$3
  local value=$4

  [[ -z $section || -z $option ]] && return

  if ! grep -q "^\[$section\]" "$file" 2>/dev/null; then
      # Add section at the end
      echo -e "\n[$section]" >>"$file"
  fi
  if ! conf_has_option "$file" "$section" "$option"; then
      # Add it
      sed -i -e "/^\[$section\]/ a\\
$option = $value
" "$file"
  else
      local sep=$(echo -ne "\x01")
      # Replace it
      sed -i -e '/^\['${section}'\]/,/^\[.*\]/ s'${sep}'^\('${option}'[ \t]*=[ \t]*\).*$'${sep}'\1'"${value}"${sep} "$file"
  fi
}

insert_scenario_value() {
  local config=$1
  local value=$2
  sed -i "s/%${value}%/${!value}/g" $config
}

write_sahara_main_conf() {
  local conf_path=$1
  local engine=$2
  insert_config_value $conf_path DEFAULT infrastructure_engine $engine
  insert_config_value $conf_path DEFAULT use_identity_api_v3 true
  insert_config_value $conf_path DEFAULT use_neutron $USE_NEUTRON
  insert_config_value $conf_path DEFAULT min_transient_cluster_active_time 30
  insert_config_value $conf_path DEFAULT node_domain ci
  insert_config_value $conf_path database connection mysql://sahara-citest:sahara-citest@localhost/sahara?charset=utf8
  insert_config_value $conf_path keystone_authtoken auth_uri http://$OPENSTACK_HOST:5000/v2.0/
  insert_config_value $conf_path keystone_authtoken identity_uri http://$OPENSTACK_HOST:35357/
  insert_config_value $conf_path keystone_authtoken admin_user $OS_USERNAME
  insert_config_value $conf_path keystone_authtoken admin_password $OS_PASSWORD
  insert_config_value $conf_path keystone_authtoken admin_tenant_name $OS_TENANT_NAME

  echo "----------- sahara.conf -----------"
  cat $conf_path
  echo "--------------- end ---------------"
}

print_python_env() {
  [ -f $SAHARA_PATH/.tox/integration/bin/pip ] && $SAHARA_PATH/.tox/integration/bin/pip freeze > $WORKSPACE/logs/python-integration-env.txt
  [ -f $SAHARA_PATH/.tox/scenario/bin/pip ] && $SAHARA_PATH/.tox/scenario/bin/pip freeze > $WORKSPACE/logs/python-scenario-env.txt
  pip freeze > $WORKSPACE/logs/python-system-env.txt
}

failure() {
  local reason=$1
  print_python_env
  echo "$reason"
  exit 1
}

start_sahara() {
  local conf_path=$1
  local conf_dir=$(dirname $1)
  mkdir $WORKSPACE/logs
  sahara-db-manage --config-file $conf_path  upgrade head || failure "Command 'sahara-db-manage' failed"
  if [ "$DISTRIBUTE_MODE" == "True" ]; then
    screen -dmS sahara-api /bin/bash -c "PYTHONUNBUFFERED=1 sahara-api --config-dir $conf_dir -d --log-file $WORKSPACE/logs/sahara-log-api.txt"
    sleep 2
    screen -dmS sahara-engine_1 /bin/bash -c "PYTHONUNBUFFERED=1 sahara-engine --config-dir $conf_dir -d --log-file $WORKSPACE/logs/sahara-log-engine-1.txt"
    screen -dmS sahara-engine_2 /bin/bash -c "PYTHONUNBUFFERED=1 sahara-engine --config-dir $conf_dir -d --log-file $WORKSPACE/logs/sahara-log-engine-2.txt"
  else
    screen -dmS sahara-all /bin/bash -c "PYTHONUNBUFFERED=1 sahara-all --config-dir $conf_dir -d --log-file $WORKSPACE/logs/sahara-log.txt"
  fi

  api_responding_timeout=30
  if ! timeout ${api_responding_timeout} sh -c "while ! curl -s http://127.0.0.1:8386/v1.1/ 2>/dev/null | grep -q 'Authentication required' ; do sleep 1; done"; then
    failure "Sahara API failed to respond within ${api_responding_timeout} seconds"
  fi
}

write_tests_conf() {
  local test_conf=$1
  local cluster_name=$2
  local addr=$(ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}')
  if [ "$USE_NEUTRON" == "true" ]; then
    NETWORK="neutron"
    TENANT_ID=$NEUTRON_LAB_TENANT_ID
  else
    NETWORK="nova-network"
    TENANT_ID=$NOVA_NET_LAB_TENANT_ID
  fi
  if [[ "$JOB_NAME" =~ scenario ]]; then
    insert_scenario_value $test_conf OS_USERNAME
    insert_scenario_value $test_conf OS_PASSWORD
    insert_scenario_value $test_conf OS_TENANT_NAME
    insert_scenario_value $test_conf OPENSTACK_HOST
    insert_scenario_value $test_conf NETWORK
    insert_scenario_value $test_conf TENANT_ID
    insert_scenario_value $test_conf cluster_name
  else
    cp $sahara_templates_configs_path/itest.conf.sample $test_conf
    insert_config_value $test_conf COMMON OS_USERNAME $OS_USERNAME
    insert_config_value $test_conf COMMON OS_PASSWORD $OS_PASSWORD
    insert_config_value $test_conf COMMON OS_TENANT_NAME $OS_TENANT_NAME
    insert_config_value $test_conf COMMON OS_TENANT_ID $TENANT_ID
    insert_config_value $test_conf COMMON OS_AUTH_URL $OS_AUTH_URL
    insert_config_value $test_conf COMMON NEUTRON_ENABLED $USE_NEUTRON
    insert_config_value $test_conf COMMON SAHARA_HOST $addr
    insert_config_value $test_conf COMMON CLUSTER_NAME $cluster_name
  fi

  echo "----------- tests config -----------"
  cat $test_conf
  echo "---------------- end ---------------"
}

run_tests() {
  local config=$1
  local plugin=$2
  local concurrency=${3:-"1"}
  echo "Integration tests are started"
  export PYTHONUNBUFFERED=1
  if [[ "$JOB_NAME" =~ scenario ]]
  then
      # Temporary use additional log file, due to wrong status code from tox scenario tests
      # tox -e scenario $config || failure "Integration tests are failed"
      tox -e scenario $config | tee tox.log
      STATUS=$(grep "\ -\ Failed" tox.log | awk '{print $3}')
      if [ "$STATUS" != "0" ]; then failure "Integration tests have failed"; fi
  else
      tox -e integration -- $plugin --concurrency=$concurrency || failure "Integration tests have failed"
  fi
}
