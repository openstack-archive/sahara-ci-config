#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

project=$(echo $JOB_NAME | awk -F '-' '{ print $2 }')
image_id=$(glance image-list | grep ubuntu-test-image | awk '{print $2}')

if [ "$project" == "sahara" ]; then
   SAHARA_PATH="$WORKSPACE"
   SAHARACLIENT_PATH=/tmp/saharaclient
   git clone https://git.openstack.org/openstack/python-saharaclient $SAHARACLIENT_PATH -b $ZUUL_BRANCH
else
   SAHARA_PATH=/tmp/sahara
   SAHARACLIENT_PATH="$WORKSPACE"
   git clone https://git.openstack.org/openstack/sahara $SAHARA_PATH -b $ZUUL_BRANCH
fi
sahara_conf_path=$SAHARA_PATH/etc/sahara/sahara.conf

# update tempest
pushd /home/jenkins/tempest/ &>/dev/null
git pull
git log --pretty=oneline -n 1
popd &>/dev/null

cd /home/jenkins

TEMPESTPLUGIN_TESTS=0
if [ -f "$SAHARA_PATH/sahara/tests/tempest/scenario/data_processing/plugin.py" ]; then
   # if the file exists, scenario tests are exposed as plugin for tempest
   TEMPESTPLUGIN_TESTS=1
else
   cp -r $SAHARA_PATH/sahara/tests/tempest tempest/
fi

cd tempest
# create tempest conf file
insert_config_value etc/tempest.conf DEFAULT lock_path /tmp
insert_config_value etc/tempest.conf identity admin_password $OS_PASSWORD
insert_config_value etc/tempest.conf identity admin_tenant_name $OS_TENANT_NAME
insert_config_value etc/tempest.conf identity admin_username $OS_USERNAME
insert_config_value etc/tempest.conf identity password $OS_PASSWORD
insert_config_value etc/tempest.conf identity tenant_name $OS_TENANT_NAME
insert_config_value etc/tempest.conf identity username $OS_USERNAME
insert_config_value etc/tempest.conf identity uri "http://$OPENSTACK_HOST:5000/v2.0/"
insert_config_value etc/tempest.conf identity uri_v3 "http://$OPENSTACK_HOST:5000/v3/"
insert_config_value etc/tempest.conf service_available neutron $USE_NEUTRON
insert_config_value etc/tempest.conf service_available sahara true
if [ "$USE_NEUTRON" == "true" ]; then
    public_network_id=$(neutron net-show "public" -f value -c id)
    insert_config_value etc/tempest.conf network public_network_id $public_network_id
fi

if [ "$TEMPESTPLUGIN_TESTS" == "0" ]; then
   # create tests file
   insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing flavor_id 2
   insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing ssh_username ubuntu
   insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing floating_ip_pool public
   insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing private_network private
   insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing fake_image_id $image_id
else
   insert_config_value etc/tempest.conf compute flavor_ref 2
   insert_config_value etc/tempest.conf scenario ssh_user ubuntu
   insert_config_value etc/tempest.conf network floating_network_name public
   insert_config_value etc/tempest.conf compute fixed_network_name private
   insert_config_value etc/tempest.conf data-processing fake_image_id $image_id
fi

enable_pypi
sudo pip install $SAHARA_PATH/. --no-cache-dir
write_sahara_main_conf $sahara_conf_path "direct" "fake"
start_sahara $sahara_conf_path

# Prepare env and install saharaclient
if [ "$TEMPESTPLUGIN_TESTS" == "0" ]; then
   TOXENV="all"
else
   TOXENV="all-plugin"
fi
export OS_TEST_TIMEOUT=5400
tox -e $TOXENV --notest
.tox/$TOXENV/bin/pip install $SAHARACLIENT_PATH/.
# temporary fix for older branches, instead of bumping them to the latest tempest
if [ "$ZUUL_BRANCH" == "stable/kilo" ] || [ "$ZUUL_BRANCH" == "stable/liberty" ]; then
   .tox/$TOXENV/bin/pip install tempest-lib
fi
# Temporary use additional log file, due to wrong status code from tox scenario tests
# tox -e $TOXENV -- tempest.scenario.data_processing.client_tests || failure "Tempest tests are failed"
tox -e $TOXENV -- tempest.scenario.data_processing.client_tests | tee tox.log
STATUS=$(grep "\ -\ Failed" tox.log | awk '{print $3}')
if [ "$STATUS" != "0" ]; then failure "Tempest tests have failed"; fi
.tox/$TOXENV/bin/pip freeze > $WORKSPACE/logs/python-tempest-env.txt
unset OS_TEST_TIMEOUT
print_python_env
