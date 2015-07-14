#!/bin/bash -xe

configs_path=$WORKSPACE/sahara-ci-config/config
eval ci_flavor_id="\'20\'"
eval medium_flavor_id="\'3\'"
eval large_flavor_id="\'4\'"

check_dependency_patch() {
  local project_name=$1
  local zuul_changes=${ZUUL_CHANGES:-$2}
  for dep in $(echo "$zuul_changes" | tr "^" "\n"); do
     cur_proj=$(echo $dep|awk -F: '{print $1}')
     [[ "$cur_proj" =~ ^"$project_name"$ ]] && return 0
  done
  return 1
}

conf_has_option() {
  local file=$1
  local section=$2
  local option=$3
  local line

  line=$(sed -ne "/^\[$section\]/,/^\[.*\]/ { /^$option[ \t]*=/ p; }" "$file")
  [ -n "$line" ]
}

enable_pypi() {
  mkdir -p ~/.pip
  export PIP_USE_MIRRORS=True
  cp $configs_path/pip.conf ~/.pip/pip.conf
}

failure() {
  local reason=$1
  print_python_env
  echo "$reason"
  exit 1
}

get_dependency() {
  local project_dir=$1
  local project_name=$2
  local branch=${ZUUL_BRANCH:-$3}
  if check_dependency_patch "$project_name"
  then
    # when patch depends on patch to some project
    pushd $(pwd)
    mkdir "$project_dir" && cd "$project_dir"
    ZUUL_PROJECT="$project_name" /usr/local/jenkins/slave_scripts/gerrit-git-prep.sh https://review.openstack.org https://review.openstack.org
    popd
  else
    git clone https://review.openstack.org/"$project_name" "$project_dir" -b "$branch"
  fi
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
  local file=$1
  local main_key=$2
  local stop_key=$3
  local sub_key=$4
  local value=$5
  local old_value=$6

  [[ -z $main_key || -z $sub_key ]] && return

  if ! scenario_has_option "$file" "$main_key" "$stop_key" "$sub_key"; then
      echo "No such keys: $main_key -> $sub_key in scenario $file file. Skip setting value $value"
  else
      local sep=$(echo -ne "\x01")
      sed -i -e '/'${main_key}':/,/'${stop_key}'/ s'${sep}'\([ \t]'${sub_key}':[ \t]\).*'${old_value}'.*$'${sep}'\1'${value}${sep} $file
  fi
}

print_python_env() {
  [ -f $SAHARA_PATH/.tox/integration/bin/pip ] && $SAHARA_PATH/.tox/integration/bin/pip freeze > $WORKSPACE/logs/python-integration-env.txt
  [ -f $SAHARA_PATH/.tox/scenario/bin/pip ] && $SAHARA_PATH/.tox/scenario/bin/pip freeze > $WORKSPACE/logs/python-scenario-env.txt
  pip freeze > $WORKSPACE/logs/python-system-env.txt
}

run_tests() {
  local vars_template=$1
  local config=$2
  local concurrency=${3:-"1"}
  echo "Integration tests are started"
  export PYTHONUNBUFFERED=1
  local scenario_credentials=$(dirname $1)/credentials.yaml.mako
  local scenario_edp=$(dirname $1)/edp.yaml
  # Temporary use additional log file, due to wrong status code from tox scenario tests
  # tox -e scenario -- --verbose -V $vars_template $scenario_common $config || failure "Integration tests are failed"
  tox -e scenario -- --verbose -V $vars_template $scenario_credentials $scenario_edp $config | tee tox.log
  STATUS=$(grep "\ -\ Failed" tox.log | awk '{print $3}')
  if [ "$STATUS" != "0" ]; then failure "Integration tests have failed"; fi
}

scenario_has_option() {
  local file=$1
  local main_key=$2
  local stop_key=$3
  local sub_key=$4
  local line

  line=$(sed -ne "/$main_key\:/,/$stop_key/ { /[ \t]$sub_key:/ p; }" "$file")
  [ -n "$line" ]
}

start_sahara() {
  local conf_path=$1
  local conf_dir=$(dirname $1)
  local mode=$2
  mkdir $WORKSPACE/logs
  sahara-db-manage --config-file $conf_path  upgrade head || failure "Command 'sahara-db-manage' failed"
  if [ "$mode" == "distribute" ]; then
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

write_sahara_main_conf() {
  local conf_path=$1
  local engine=$2
  local plugin=$3
  insert_config_value $conf_path DEFAULT infrastructure_engine $engine
  insert_config_value $conf_path DEFAULT api_workers 4
  insert_config_value $conf_path DEFAULT use_identity_api_v3 true
  insert_config_value $conf_path DEFAULT use_neutron $USE_NEUTRON
  insert_config_value $conf_path DEFAULT min_transient_cluster_active_time 30
  insert_config_value $conf_path DEFAULT node_domain ci
  insert_config_value $conf_path DEFAULT plugins $plugin
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

write_tests_conf() {
  local template_vars_conf=$1
  local cluster_name=$2
  local image_prefix=$3
  local image_name=$4
  if [ "$USE_NEUTRON" == "true" ]; then
    NETWORK="neutron"
  else
    NETWORK="nova-network"
  fi
echo "[DEFAULT]
OS_USERNAME: $OS_USERNAME
OS_PASSWORD: $OS_PASSWORD
OS_TENANT_NAME: $OS_TENANT_NAME
OPENSTACK_HOST: $OPENSTACK_HOST
network_type: $NETWORK
${image_prefix}_image: $image_name
cluster_name: $cluster_name
ci_flavor_id: $ci_flavor_id
medium_flavor_id: $medium_flavor_id
large_flavor_id: $large_flavor_id
" | tee ${template_vars_conf}
}
