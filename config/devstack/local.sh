#!/bin/bash -x
TOP_DIR=$(cd $(dirname "$0") && pwd)
ADMIN_RCFILE=$TOP_DIR/openrc
PRIVATE_CIDR=10.0.0.0/24
CINDER_CONF=/etc/cinder/cinder.conf
NOVA_CONF=/etc/nova/nova.conf
GLANCE_CACHE_CONF=/etc/glance/glance-cache.conf
KEYSTONE_CONF=/etc/keystone/keystone.conf
HEAT_CONF=/etc/heat/heat.conf
MYSQL_CONF=/etc/mysql/my.cnf

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

VANILLA_2_6_0_IMAGE_PATH=/home/ubuntu/images/vanilla_2.6.0_u14.qcow2
VANILLA_2_7_1_IMAGE_PATH=/home/ubuntu/images/vanilla_2.7.1_u14.qcow2
HDP_2_0_6_IMAGE_PATH=/home/ubuntu/images/hdp_2.0.6_c6.6.qcow2
CENTOS_CDH_5_3_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.3.0_c6.6.qcow2
UBUNTU_CDH_5_3_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.3.0_u12.qcow2
UBUNTU_CDH_5_4_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.4.0_u12.qcow2
CENTOS_CDH_5_4_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.4.0_c6.6.qcow2
SPARK_1_0_0_IMAGE_PATH=/home/ubuntu/images/spark_1.0.0_u14.qcow2
SPARK_1_3_1_IMAGE_PATH=/home/ubuntu/images/spark_1.3.1_u14.qcow2
MAPR_4_0_2_MRV2_IMAGE_PATH=/home/ubuntu/images/mapr_4.0.2.mrv2_u14.qcow2
UBUNTU_12_04_IMAGE_PATH=/home/ubuntu/images/ubuntu-12.04-server-cloudimg-amd64-disk1.img

# setup ci tenant and ci users
CI_TENANT_ID=$(keystone tenant-create --name ci --description 'CI tenant' | grep -w id | get_field 2)
CI_USER_ID=$(keystone user-create --name ci-user --tenant_id $CI_TENANT_ID --pass nova |  grep -w id | get_field 2)
ADMIN_USER_ID=$(keystone user-list | grep -w admin | get_field 1)
MEMBER_ROLE_ID=$(keystone role-list | grep -w Member | get_field 1)
HEAT_OWNER_ROLE_ID=$(keystone role-list | grep -w heat_stack_owner | get_field 1)
keystone user-role-add --user $CI_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
#keystone user-role-add --user $CI_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
#keystone user-role-add --user $ADMIN_USER_ID --role $HEAT_OWNER_ROLE_ID --tenant $CI_TENANT_ID
_MEMBER_ROLE_ID=$(keystone role-list | grep -w _member_ | get_field 1)
keystone user-role-add --user $ADMIN_USER_ID --role $_MEMBER_ROLE_ID --tenant $CI_TENANT_ID
ADMIN_ROLE_ID=$(keystone role-list | grep -w admin | get_field 1)
keystone user-role-add --user $CI_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID

# setup quota for ci tenant
nova-manage project quota $CI_TENANT_ID --key ram --value 200000
nova-manage project quota $CI_TENANT_ID --key instances --value 64
nova-manage project quota $CI_TENANT_ID --key cores --value 150
cinder quota-update --volumes 100 $CI_TENANT_ID
cinder quota-update --gigabytes 2000 $CI_TENANT_ID
if $USE_NEUTRON; then
  neutron quota-update --tenant_id $CI_TENANT_ID --port 64 --floatingip 64 --security-group 1000 --security-group-rule 10000
else
  nova quota-update --floating-ips 64 --security-groups 1000 --security-group-rules 10000 $CI_TENANT_ID
fi

# create qa flavor
nova flavor-create --is-public true qa-flavor 20 2048 40 1
nova flavor-delete m1.small
nova flavor-create --is-public true m1.small 2 1024 20 1

# switch to ci-user credentials
source $ADMIN_RCFILE ci-user ci

# add images for tests
glance image-create --name $(basename -s .qcow2 $VANILLA_2_6_0_IMAGE_PATH) --file $VANILLA_2_6_0_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.6.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name $(basename -s .qcow2 $VANILLA_2_7_1_IMAGE_PATH) --file $VANILLA_2_7_1_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.7.1'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'='ubuntu'
glance image-create --name $(basename -s .qcow2 $HDP_2_0_6_IMAGE_PATH) --file $HDP_2_0_6_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_2.0.6'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'='cloud-user'
glance image-create --name $(basename -s .qcow2 $CENTOS_CDH_5_3_0_IMAGE_PATH) --file $CENTOS_CDH_5_3_0_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5.3.0'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="cloud-user"
glance image-create --name $(basename -s .qcow2 $UBUNTU_CDH_5_3_0_IMAGE_PATH) --file $UBUNTU_CDH_5_3_0_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5.3.0'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="ubuntu"
glance image-create --name $(basename -s .qcow2 $UBUNTU_CDH_5_4_0_IMAGE_PATH) --file $UBUNTU_CDH_5_4_0_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5.4.0'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="ubuntu"
glance image-create --name $(basename -s .qcow2 $CENTOS_CDH_5_4_0_IMAGE_PATH) --file $CENTOS_CDH_5_4_0_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_5.4.0'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'="cloud-user"
glance image-create --name $(basename -s .qcow2 $SPARK_1_0_0_IMAGE_PATH) --file $SPARK_1_0_0_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_spark'='True' --property '_sahara_tag_1.0.0'='True'  --property '_sahara_username'="ubuntu"
glance image-create --name $(basename -s .qcow2 $SPARK_1_3_1_IMAGE_PATH) --file $SPARK_1_3_1_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_spark'='True' --property '_sahara_tag_1.3.1'='True'  --property '_sahara_username'="ubuntu"
glance image-create --name $(basename -s .qcow2 $MAPR_4_0_2_MRV2_IMAGE_PATH) --file $MAPR_4_0_2_MRV2_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_mapr'='True' --property '_sahara_tag_4.0.2.mrv2'='True'  --property '_sahara_username'="ubuntu"
glance image-create --name ubuntu-test-image --file $UBUNTU_12_04_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true
glance image-create --name fake_image --file $UBUNTU_12_04_IMAGE_PATH  --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' --property '_sahara_tag_fake'='True' --property '_sahara_tag_0.1'='True' --property '_sahara_username'='ubuntu'
glance image-update --name ubuntu-12.04 --property '_sahara_tag_ci'='True' ubuntu-12.04-server-cloudimg-amd64-disk1
glance image-update --name ubuntu-14.04 trusty-server-cloudimg-amd64-disk1

if $USE_NEUTRON; then
  # rename admin private network
  neutron net-update private --name admin-private
  # create neutron private network for ci tenant
  PRIVATE_NET_ID=$(neutron net-create private | grep -w id | get_field 2)
  SUBNET_ID=$(neutron subnet-create --name ci-subnet $PRIVATE_NET_ID $PRIVATE_CIDR | grep -w id | get_field 2)
  ROUTER_ID=$(neutron router-create ci-router | grep -w id | get_field 2)
  PUBLIC_NET_ID=$(neutron net-list | grep -w public | get_field 1)
  FORMAT=" --request-format xml"
  neutron router-interface-add $ROUTER_ID $SUBNET_ID
  neutron router-gateway-set $ROUTER_ID $PUBLIC_NET_ID
  neutron subnet-update ci-subnet --dns_nameservers list=true 8.8.8.8 8.8.4.4
else
  PRIVATE_NET_ID=$(nova net-list | grep -w private | get_field 1)
fi

# create keypair for UI tests
#nova --os-username ci-user --os-password nova --os-tenant-name ci keypair-add public-jenkins > /dev/null

#enable auto assigning of floating ips
#ps -ef | grep -i "nova-network" | grep -v grep | awk '{print $2}' | xargs sudo kill -9
#sudo sed -i -e "s/default_floating_pool = public/&\nauto_assign_floating_ip = True/g" /etc/nova/nova.conf

# setup security groups
if $USE_NEUTRON; then
  #this actions is workaround for bug: https://bugs.launchpad.net/neutron/+bug/1263997
  #CI_DEFAULT_SECURITY_GROUP_ID=$(neutron security-group-list --tenant_id $CI_TENANT_ID | grep ' default ' | awk '{print $2}')
  CI_DEFAULT_SECURITY_GROUP_ID=$(nova secgroup-list | grep -w default | get_field 1)
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

#create Sahara endpoint for tests
service_id=$(keystone service-create --name sahara --type data_processing --description "Data Processing Service" | grep -w id | get_field 2)
keystone endpoint-create --service-id $service_id --publicurl 'http://localhost:8386/v1.1/$(tenant_id)s' --adminurl 'http://localhost:8386/v1.1/$(tenant_id)s' --internalurl 'http://localhost:8386/v1.1/$(tenant_id)s' --region RegionOne
# create second endpoint due to bug: #1356053
service_id=$(keystone service-create --name sahara --type data-processing --description "Data Processing Service" | grep -w id | get_field 2)
keystone endpoint-create --service-id $service_id --publicurl 'http://localhost:8386/v1.1/$(tenant_id)s' --adminurl 'http://localhost:8386/v1.1/$(tenant_id)s' --internalurl 'http://localhost:8386/v1.1/$(tenant_id)s' --region RegionOne

# Setup Ceph
echo "R" | bash $TOP_DIR/micro-osd.sh /home/ubuntu/ceph

#setup expiration time for keystone
iniset $KEYSTONE_CONF token expiration 86400
sudo service apache2 restart

# Setup Ceph backend for Cinder
inidelete $CINDER_CONF DEFAULT default_volume_type
inidelete $CINDER_CONF DEFAULT enabled_backends
inidelete $CINDER_CONF lvmdriver-1 volume_clear
inidelete $CINDER_CONF lvmdriver-1 volume_group
inidelete $CINDER_CONF lvmdriver-1 volume_driver
inidelete $CINDER_CONF lvmdriver-1 volume_backend_name
iniset $CINDER_CONF DEFAULT volume_driver cinder.volume.drivers.rbd.RBDDriver
iniset $CINDER_CONF DEFAULT rbd_pool data
iniset $GLANCE_CACHE_CONF DEFAULT image_cache_stall_time 43200

#Setup Heat
iniset $HEAT_CONF database max_pool_size 1000
iniset $HEAT_CONF database max_overflow  1000

# Setup path for Nova instances
#iniset $NOVA_CONF DEFAULT instances_path '/srv/nova'

# set mysql max allowed connections to 1000
sudo bash -c "source $TOP_DIR/functions && \
    iniset $MYSQL_CONF mysqld max_connections 1000"
sudo service mysql restart
sleep 5

# add squid iptables rule if not exists
squid_port="3128"
sudo iptables-save | grep "$squid_port"
if [ "$?" == "1" ]; then
  if $USE_NEUTRON; then
    sudo iptables -t nat -A PREROUTING -i br-ex -p tcp --dport 80 -m comment --comment "Redirect traffic to Squid" -j DNAT --to 172.18.168.42:$squid_port
  else
    sudo iptables -t nat -A PREROUTING -i br100 -p tcp --dport 80 -m comment --comment "Redirect traffic to Squid" -j DNAT --to 172.18.168.43:$squid_port
  fi
fi

# Restart OpenStack services
screen -X -S stack quit
killall -9 python
killall -9 "/usr/bin/python"
screen -dm -c $TOP_DIR/stack-screenrc
sleep 10

echo "|---------------------------------------------------|"
echo "| ci-tenant-id | $CI_TENANT_ID"
echo "|---------------------------------------------------|"
echo "| ci-private-network-id | $PRIVATE_NET_ID"
echo "|---------------------------------------------------|"
