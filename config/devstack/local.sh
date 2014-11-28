#!/bin/bash -x
TOP_DIR=$(cd $(dirname "$0") && pwd)
ADMIN_RCFILE=$TOP_DIR/openrc
PRIVATE_CIDR=10.0.0.0/24

if [ -e "$ADMIN_RCFILE" ]; then
    source $ADMIN_RCFILE admin admin
else
    echo "Can't source '$ADMIN_RCFILE'!"
    exit 1
fi

if [[ `nova endpoints | grep neutron` != "" ]]; then
    USE_NEUTRON=true
else
    USE_NEUTRON=false
fi

VANILLA23_IMAGE_PATH=/home/ubuntu/images/sahara-icehouse-vanilla-2.3.0-ubuntu-13.10.qcow2
VANILLA24_IMAGE_PATH=/home/ubuntu/images/sahara-icehouse-vanilla-2.4.1-ubuntu-13.10.qcow2
VANILLA_IMAGE_PATH=/home/ubuntu/images/sahara-icehouse-vanilla-1.2.1-ubuntu-13.10.qcow2
HDP1_IMAGE_PATH=/home/ubuntu/images/centos-6_4-64-hdp-1.3-sk
HDP2_IMAGE_PATH=/home/ubuntu/images/centos-6_4-64-hdp-2-0.qcow2
CENTOS_CDH_IMAGE_PATH=/home/ubuntu/images/centos_sahara_cloudera_latest.qcow2
UBUNTU_CDH_IMAGE_PATH=/home/ubuntu/images/ubuntu_sahara_cloudera_latest.qcow2
SPARK_IMAGE_PATH=/home/ubuntu/images/sahara_spark_latest.qcow2
NATIVE_UBUNTU_IMAGE_PATH=/home/ubuntu/images/ubuntu-12.04-server-cloudimg-amd64-disk1.img

# setup ci tenant and ci users
CI_TENANT_ID=$(keystone tenant-create --name ci --description 'CI tenant' | grep id | awk '{print $4}')
CI_USER_ID=$(keystone user-create --name ci-user --tenant_id $CI_TENANT_ID --pass nova |  grep id | awk '{print $4}')
ADMIN_USER_ID=$(keystone user-list | grep admin | awk '{print $2}' | head -n 1)
MEMBER_ROLE_ID=$(keystone role-list | grep Member | awk '{print $2}')
HEAT_OWNER_ROLE_ID=$(keystone role-list | grep heat_stack_owner | awk '{print $2}')
keystone user-role-add --user $CI_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $CI_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
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
nova quota-update --tenant_id $CI_TENANT_ID --security-groups 100
nova quota-update --tenant_id $CI_TENANT_ID --security-group-rules 100

# create qa flavor
nova flavor-create --is-public true qa-flavor 20 2048 40 1
nova flavor-delete m1.small
nova flavor-create --is-public true m1.small 2 1024 20 1

# add images for tests
glance image-create --name ubuntu-vanilla-2.3-latest --file $VANILLA23_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.3.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name ubuntu-vanilla-2.4-latest --file $VANILLA24_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.4.1'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name sahara-itests-ci-vanilla-image --file $VANILLA_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name sahara-itests-ci-hdp-image-jdk-iptables-off --file $HDP1_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_1.3.2'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'='root'
glance image-create --name centos-6_4-64-hdp-2-0-hw --file $HDP2_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.0.6'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'='root'
glance image-create --name centos_cdh_latest --file $CENTOS_CDH_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="cloud-user"
# temporary using native ubuntu 12.04 for CDH tests on Ubuntu
#glance image-create --name ubuntu_cdh_latest --file $UBUNTU_CDH_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="ubuntu"
glance image-update --name ubuntu-12.04 --property '_sahara_tag_ci'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="ubuntu" ubuntu-12.04-server-cloudimg-amd64-disk1
glance image-create --name sahara_spark_latest --file $SPARK_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_spark'='True' --property '_sahara_tag_1.0.0'='True'  --property '_sahara_username'="ubuntu"
glance image-create --name ubuntu-test-image --file $NATIVE_UBUNTU_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true

# switch to ci-user credentials
source $ADMIN_RCFILE ci-user ci

if $USE_NEUTRON; then
  # create neutron private network for ci tenant
  PRIVATE_NET_ID=$(neutron net-create ci-private | grep id | awk '{print $4}' | head -1)
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

# enable auto assigning of floating ips
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

echo "|---------------------------------------------------|"
echo "| ci-tenant-id | $CI_TENANT_ID"
echo "|---------------------------------------------------|"
echo "| ci-private-network-id | $PRIVATE_NET_ID"
echo "|---------------------------------------------------|"
