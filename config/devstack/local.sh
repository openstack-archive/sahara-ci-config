export OS_PASSWORD=
export OS_USERNAME=
export OS_TENANT_NAME=
export OS_AUTH_URL=http://127.0.0.1:5000/v2.0/

VANILLA_IMAGE_PATH=/home/ubuntu/images/savanna-itests-ci-vanilla-image
HDP_IMAGE_PATH=/home/ubuntu/images/savanna-itests-ci-hdp-image-jdk-iptables-off.qcow2
UBUNTU_IMAGE_PATH=/home/ubuntu/images/ubuntu-12.04.qcow2
IDH_IMAGE_PATH=/home/ubuntu/images/intel-noepel.qcow2

# setup ci tenant and ci users

CI_TENANT_ID=$(keystone tenant-create --name ci --description 'CI tenant' | grep id | awk '{print $4}')
CI_USER_ID=$(keystone user-create --name ci-user --tenant_id $CI_TENANT_ID --pass nova |  grep id | awk '{print $4}')
ADMIN_USER_ID=$(keystone user-list | grep admin | awk '{print $2}')
MEMBER_ROLE_ID=$(keystone role-list | grep Member | awk '{print $2}')
keystone user-role-add --user $CI_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $MEMBER_ROLE_ID --tenant $CI_TENANT_ID
_MEMBER_ROLE_ID=$(keystone role-list | grep _member_ | awk '{print $2}')
keystone user-role-add --user $ADMIN_USER_ID --role $_MEMBER_ROLE_ID --tenant $CI_TENANT_ID
ADMIN_ROLE_ID=$(keystone role-list | grep admin | awk '{print $2}')
keystone user-role-add --user $CI_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID
keystone user-role-add --user $ADMIN_USER_ID --role $ADMIN_ROLE_ID --tenant $CI_TENANT_ID

# setup quota for ci tenant

nova-manage project quota $CI_TENANT_ID --key ram --value 200000
nova-manage project quota $CI_TENANT_ID --key instances --value 100
nova-manage project quota $CI_TENANT_ID --key cores --value 150
cinder quota-update --volumes 100 $CI_TENANT_ID
cinder quota-update --gigabytes 2000 $CI_TENANT_ID
neutron quota-update --tenant_id $CI_TENANT_ID --port 64
neutron quota-update --tenant_id $CI_TENANT_ID --floatingip 64
# create qa flavor

nova flavor-create --is-public true qa-flavor 20 1024 40 1

# add images for tests

glance image-create --name savanna-itests-ci-vanilla-image --file $VANILLA_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_savanna_tag_ci'='True' --property '_savanna_tag_1.2.1'='True' --property '_savanna_tag_1.1.2'='True' --property '_savanna_tag_vanilla'='True' --property '_savanna_username'='ubuntu'
glance image-create --name savanna-itests-ci-hdp-image-jdk-iptables-off --file $HDP_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_savanna_tag_ci'='True' --property '_savanna_tag_1.3.2'='True' --property '_savanna_tag_hdp'='True' --property '_savanna_username'='root'
glance image-create --name ubuntu-12.04 --file $UBUNTU_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true
glance image-create --name intel-noepel --file $IDH_IMAGE_PATH --disk-format qcow2 --container-format bare --is-public=true --property '_savanna_tag_ci'='True' --property '_savanna_tag_2.5.1'='True' --property '_savanna_tag_idh'='True' --property '_savanna_username'='cloud-user'

# make Neutron networks shared

PRIVATE_NET_ID=$(neutron net-list | grep private | awk '{print $2}')
PUBLIC_NET_ID=$(neutron net-list | grep public | awk '{print $2}')
FORMAT=" --request-format xml"

neutron net-update $FORMAT $PRIVATE_NET_ID --shared True
neutron net-update $FORMAT $PUBLIC_NET_ID --shared True

neutron subnet-update private-subnet --dns_nameservers list=true 8.8.8.8 8.8.4.4

nova --os-username ci-user --os-password nova --os-tenant-name ci keypair-add public-jenkins > /dev/null
# setup security groups (nova-network only)

#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

# enable auto assigning of floating ips

#ps -ef | grep -i "nova-network" | grep -v grep | awk '{print $2}' | xargs sudo kill -9
#sudo sed -i -e "s/default_floating_pool = public/&\nauto_assign_floating_ip = True/g" /etc/nova/nova.conf
#screen -dmS nova-network /bin/bash -c "/usr/local/bin/nova-network --config-file /etc/nova/nova.conf || touch /opt/stack/status/stack/n-net.failure"

# switch to ci-user credentials

#export OS_PASSWORD=nova
#export OS_USERNAME=ci-user
#export OS_TENANT_NAME=ci
#export OS_AUTH_URL=http://172.18.168.42:5000/v2.0/

# setup security groups

#nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
#nova secgroup-add-rule default tcp 22 22 0.0.0.0/0

