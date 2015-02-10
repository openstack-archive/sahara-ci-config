#!/bin/bash -x
TOP_DIR=$(cd $(dirname "$0") && pwd)
ADMIN_RCFILE=$TOP_DIR/openrc
PRIVATE_CIDR=10.0.0.0/24
CINDER_CONF=/etc/cinder/cinder.conf
NOVA_CONF=/etc/nova/nova.conf

source $TOP_DIR/functions-common

if [ -e "$ADMIN_RCFILE" ]; then
    source $ADMIN_RCFILE admin admin
else
    echo "Can't source '$ADMIN_RCFILE'!"
    exit 1
fi

if [[ $(nova endpoints | grep neutron) != "" ]]; then
    USE_NEUTRON=true
else
    USE_NEUTRON=false
fi

VANILLA24_IMAGE_PATH=/home/ubuntu/images/sahara-vanilla-2.4.1-ubuntu-14.04.qcow2
VANILLA26_IMAGE_PATH=/home/ubuntu/images/sahara-vanilla-2.6.0-ubuntu-14.04.qcow2
VANILLA_IMAGE_PATH=/home/ubuntu/images/sahara-vanilla-1.2.1-ubuntu-14.04.qcow2
HDP1_IMAGE_PATH=/home/ubuntu/images/centos_6-6_hdp-1.qcow2
HDP2_IMAGE_PATH=/home/ubuntu/images/centos_6-6_hdp-2.qcow2
CENTOS_CDH_IMAGE_PATH=/home/ubuntu/images/centos_sahara_cloudera_latest.qcow2
UBUNTU_CDH_IMAGE_PATH=/home/ubuntu/images/ubuntu_sahara_cloudera_latest.qcow2
SPARK_IMAGE_PATH=/home/ubuntu/images/sahara_spark_latest.qcow2
NATIVE_UBUNTU_IMAGE_PATH=/home/ubuntu/images/ubuntu-12.04-server-cloudimg-amd64-disk1.img

# setup ci tenant and ci users
CI_TENANT_ID=$(keystone tenant-create --name ci --description 'CI tenant' | grep -w id | awk '{print $4}')
CI_USER_ID=$(keystone user-create --name ci-user --tenant_id $CI_TENANT_ID --pass nova |  grep -w id | awk '{print $4}')
ADMIN_USER_ID=$(keystone user-list | grep admin | awk '{print $2}' | head -n 1)
MEMBER_ROLE_ID=$(keystone role-list | grep Member | awk '{print $2}')
HEAT_OWNER_ROLE_ID=$(keystone role-list | grep heat_stack_owner | awk '{print $2}')
keystone user-role-add --user $CI_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
#keystone user-role-add --user $CI_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
#keystone user-role-add --user $ADMIN_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
_MEMBER_ROLE_ID=$(keystone role-list | grep _member_ | awk '{print $2}')
keystone user-role-add --user $ADMIN_USER_ID --role $_MEMBER_ROLE_ID --tenant $CI_TENANT_ID
ADMIN_ROLE_ID=$(keystone role-list | grep admin | awk '{print $2}')
keystone user-role-add --user $CI_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID

# setup quota for ci tenant
nova-manage project quota $CI_TENANT_ID --key ram --value 200000
nova-manage project quota $CI_TENANT_ID --key instances --value 64
nova-manage project quota $CI_TENANT_ID --key cores --value 150
cinder quota-update --volumes 100 $CI_TENANT_ID
cinder quota-update --gigabytes 2000 $CI_TENANT_ID
if $USE_NEUTRON; then
  neutron quota-update --tenant_id $CI_TENANT_ID --port 64
  neutron quota-update --tenant_id $CI_TENANT_ID --floatingip 64
else
  nova quota-update --floating-ips 64 $CI_TENANT_ID
fi
nova quota-update --security-groups 1000 $CI_TENANT_ID
nova quota-update --security-group-rules 10000 $CI_TENANT_ID

# create qa flavor
nova flavor-create --is-public true qa-flavor 20 2048 40 1
nova flavor-delete m1.small
nova flavor-create --is-public true m1.small 2 1024 20 1

# add images for tests
glance image-create --name ubuntu_vanilla_1_latest --file $VANILLA_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name ubuntu_vanilla_2.4_latest --file $VANILLA24_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.4.1'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name ubuntu_vanilla_2.6_latest --file $VANILLA26_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.6.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name sahara_hdp_1_latest --file $HDP1_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.3.2'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'='root'
glance image-create --name sahara_hdp_2_latest --file $HDP2_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.0.6'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'='root'
glance image-create --name centos_cdh_latest --file $CENTOS_CDH_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="cloud-user"
glance image-create --name ubuntu_cdh_latest --file $UBUNTU_CDH_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="ubuntu"
glance image-create --name sahara_spark_latest --file $SPARK_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_spark'='True' --property '_sahara_tag_1.0.0'='True'  --property '_sahara_username'="ubuntu"
glance image-create --name ubuntu-test-image --file $NATIVE_UBUNTU_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true

# switch to ci-user credentials
source $ADMIN_RCFILE ci-user ci

if $USE_NEUTRON; then
  # rename admin private network
  neutron net-update private --name admin-private
  # create neutron private network for ci tenant
  PRIVATE_NET_ID=$(neutron net-create private | grep id | awk '{print $4}' | head -1)
  SUBNET_ID=$(neutron subnet-create --name ci-subnet $PRIVATE_NET_ID $PRIVATE_CIDR | grep id | awk '{print $4}' | sed -n 2p)
  ROUTER_ID=$(neutron router-create ci-router | grep id | awk '{print $4}' | head -1)
  PUBLIC_NET_ID=$(neutron net-list | grep public | awk '{print $2}')
  FORMAT=" --request-format xml"
  neutron router-interface-add $ROUTER_ID $SUBNET_ID
  neutron router-gateway-set $ROUTER_ID $PUBLIC_NET_ID
  neutron subnet-update ci-subnet --dns_nameservers list=true 8.8.8.8 8.8.4.4
else
  PRIVATE_NET_ID=$(nova net-list | grep private | awk '{print $2}')
fi

nova --os-username ci-user --os-password nova --os-tenant-name ci keypair-add public-jenkins > /dev/null

#enable auto assigning of floating ips
#ps -ef | grep -i "nova-network" | grep -v grep | awk '{print $2}' | xargs sudo kill -9
#sudo sed -i -e "s/default_floating_pool = public/&\nauto_assign_floating_ip = True/g" /etc/nova/nova.conf
#screen -dmS nova-network /bin/bash -c "/usr/local/bin/nova-network --config-file /etc/nova/nova.conf || touch /opt/stack/status/stack/n-net.failure"

#setup expiration time for keystone
sudo sed -i '/^\[token\]/a expiration=86400' /etc/keystone/keystone.conf
sudo service apache2 restart

# setup security groups
if $USE_NEUTRON; then
  #this actions is workaround for bug: https://bugs.launchpad.net/neutron/+bug/1263997
  #CI_DEFAULT_SECURITY_GROUP_ID=$(neutron security-group-list --tenant_id $CI_TENANT_ID | grep ' default ' | awk '{print $2}')
  CI_DEFAULT_SECURITY_GROUP_ID=$(nova secgroup-list | grep ' default ' | get_field 1)
  neutron security-group-rule-create --tenant_id $CI_TENANT_ID --protocol icmp --direction ingress $CI_DEFAULT_SECURITY_GROUP_ID
  neutron security-group-rule-create --tenant_id $CI_TENANT_ID --protocol icmp --direction egress $CI_DEFAULT_SECURITY_GROUP_ID
  neutron security-group-rule-create --tenant_id $CI_TENANT_ID --protocol tcp --port-range-min 1 --port-range-max 65535 --direction ingress $CI_DEFAULT_SECURITY_GROUP_ID
  neutron security-group-rule-create --tenant_id $CI_TENANT_ID --protocol tcp --port-range-min 1 --port-range-max 65535 --direction egress $CI_DEFAULT_SECURITY_GROUP_ID
  neutron security-group-rule-create --tenant_id $CI_TENANT_ID --protocol udp --port-range-min 1 --port-range-max 65535 --direction egress $CI_DEFAULT_SECURITY_GROUP_ID
  neutron security-group-rule-create --tenant_id $CI_TENANT_ID --protocol udp --port-range-min 1 --port-range-max 65535 --direction ingress $CI_DEFAULT_SECURITY_GROUP_ID
else
  nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
fi

#create Sahara endpoint for UI tests
keystone service-create --name sahara --type data_processing --description "Data Processing Service"
keystone endpoint-create --service sahara --publicurl 'http://localhost:8386/v1.1/$(tenant_id)s' --adminurl 'http://localhost:8386/v1.1/$(tenant_id)s' --internalurl 'http://localhost:8386/v1.1/$(tenant_id)s' --region RegionOne

# Setup Ceph
echo "R" | bash $TOP_DIR/micro-osd.sh /srv/ceph

# Setup Ceph backend for Cinder
inidelete $CINDER_CONF DEFAULT default_volume_type
inidelete $CINDER_CONF DEFAULT enabled_backends
inidelete $CINDER_CONF lvmdriver-1 volume_clear
inidelete $CINDER_CONF lvmdriver-1 volume_group
inidelete $CINDER_CONF lvmdriver-1 volume_driver
inidelete $CINDER_CONF lvmdriver-1 volume_backend_name
iniset    $CINDER_CONF DEFAULT volume_driver cinder.volume.drivers.rbd.RBDDriver
iniset    $CINDER_CONF DEFAULT rbd_pool data

# Setup path for Nova instances
iniset $NOVA_CONF DEFAULT instances_path '/srv/nova'

# Restart OpenStack services
screen -X -S stack quit
screen -dm -c $TOP_DIR/stack-screenrc
sleep 10

echo "|---------------------------------------------------|"
echo "| ci-tenant-id | $CI_TENANT_ID"
echo "|---------------------------------------------------|"
echo "| ci-private-network-id | $PRIVATE_NET_ID"
echo "|---------------------------------------------------|"
