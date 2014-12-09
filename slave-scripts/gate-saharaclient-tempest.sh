#!/bin/bash

. $FUNCTION_PATH

check_openstack_host

SAHARA_PATH=$1
TEMPEST=True
IMAGE_ID=$(glance image-list | grep ubuntu-test-image | awk '{print $2}')
if $USE_NEUTRON; then
  private_subnet="ci-private"
else
  private_subnet="private"
fi

cd /home/jenkins

cp -r $WORKSPACE/saharaclient/tests/tempest tempest/

cd tempest

echo "[DEFAULT]
lock_path = /tmp

[identity]
admin_password = nova
admin_tenant_name = ci
admin_username = ci-user
password = nova
tenant_name = ci
uri = http://$OPENSTACK_HOST:5000/v2.0/
uri_v3 = http://$OPENSTACK_HOST:5000/v3/
username = ci-user

[service_available]
neutron = $USE_NEUTRON
sahara = true
" > etc/tempest.conf

echo "[data_processing]
flavor_id=2
sahara_url=http://localhost:8386/v1.1/$TENANT_ID
ssh_username=ubuntu
floating_ip_pool=public
private_network=$private_subnet
fake_image_id=$IMAGE_ID
" > tempest/scenario/data_processing/etc/sahara_tests.conf

create_database
enable_pypi

sudo pip install $SAHARA_PATH/.
write_sahara_main_conf $SAHARA_PATH/etc/sahara/sahara.conf
start_sahara $SAHARA_PATH/etc/sahara/sahara.conf

tox -e all -- tempest.scenario.data_processing.client_tests
