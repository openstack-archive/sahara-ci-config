#!/bin/bash -xe

# source CI credentials
. /home/jenkins/ci_openrc
# source main functions
. $FUNCTION_PATH/functions-common.sh

project=$(echo $JOB_NAME | awk -F '-' '{ print $2 }')
image_id=$(glance image-list | grep ubuntu-test-image | awk '{print $2}')

if [ "$project" == "sahara" ]; then
   SAHARA_PATH="$WORKSPACE"
   git clone http://github.com/openstack/python-saharaclient /tmp/saharaclient
   cd /tmp/saharaclient
   sudo pip install -U -r requirements.txt
   sudo pip install .
else
   SAHARA_PATH=/tmp/sahara
   git clone http://github.com/openstack/sahara $SAHARA_PATH
   sudo pip install .
fi
sahara_conf_path=$SAHARA_PATH/etc/sahara/sahara.conf

cd /home/jenkins
cp -r $SAHARA_PATH/sahara/tests/tempest tempest/

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

# create tests file
[ "$USE_NEUTRON" == "true" ] && tenant_id=$NEUTRON_LAB_TENANT_ID
[ "$USE_NEUTRON" == "false" ] && tenant_id=$NOVA_NET_LAB_TENANT_ID
insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing flavor_id 2
insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing sahara_url "http://localhost:8386/v1.1/$tenant_id"
insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing ssh_username ubuntu
insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing floating_ip_pool public
insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing private_network private
insert_config_value tempest/scenario/data_processing/etc/sahara_tests.conf data_processing fake_image_id $image_id

enable_pypi
sudo pip install $SAHARA_PATH/.
insert_config_value $sahara_conf_path DEFAULT plugins fake
write_sahara_main_conf $sahara_conf_path "direct"
start_sahara $sahara_conf_path
# Temporary use additional log file, due to wrong status code from tox scenario tests
# tox -e all -- tempest.scenario.data_processing.client_tests || failure "Tempest tests are failed"
tox -e all -- tempest.scenario.data_processing.client_tests | tee tox.log
STATUS=$(grep "\ -\ Failed" tox.log | awk '{print $3}')
[ "$STATUS" != "0" ] && failure "Tempest tests have failed"
print_python_env
