#!/bin/bash -x

#this is to fix bug with testtools==0.9.35
#sed 's/testtools>=0.9.32/testtools==0.9.34/' -i test-requirements.txt

. $FUNCTION_PATH

check_openstack_host

sudo pip install .

SAHARA_PATH=$1
TEMPEST=true

cd $WORKSPACE

cp -r saharaclient/tests/tempest tempest/

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
" > scenario/data_processing/etc/sahara_tests.conf

create_database
enable_pypi

write_sahara_main_conf $SAHARA_PATH/etc/sahara/sahara.conf
start_sahara $SAHARA_PATH/etc/sahara/sahara.conf

tox -e all -- tempest.scenario.data_processing.client_tests
