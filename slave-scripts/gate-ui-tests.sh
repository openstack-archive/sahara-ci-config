#!/bin/bash -e

. $FUNCTION_PATH

check_openstack_host

sudo iptables -F
if [ ! -d saharadashboard ]
then
   DASHBOARD_PATH=$(pwd)/sahara-dashboard
   git clone https://git.openstack.org/openstack/sahara-dashboard
else
   DASHBOARD_PATH=$(pwd)
fi

create_database

#screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16
screen -dmS display sudo X
export DISPLAY=:0
enable_pypi

SAHARA_DIR=$HOME/sahara
rm -rf $SAHARA_DIR
git clone https://git.openstack.org/openstack/sahara $SAHARA_DIR
cd $SAHARA_DIR
write_sahara_main_conf $SAHARA_DIR/etc/sahara/sahara.conf
sudo pip install .
start_sahara $SAHARA_DIR/etc/sahara/sahara.conf

if [ "$FAILURE" != 0 ]; then
    exit 1
fi

sudo service apache2 restart
sleep 5

TEST_IMAGE=uitests-$RANDOM
glance image-create --name $TEST_IMAGE --disk-format qcow2 --container-format bare < /proc/uptime

echo "
[common]
base_url = 'http://localhost'
user = 'ci-user'
password = 'nova'
tenant = 'ci'
flavor = 'qa-flavor'
cluster_name = '$PREV_BUILD-selenium'
neutron_management_network = 'private'
floating_ip_pool = 'public'
keystone_url = 'http://$OPENSTACK_HOST:5000/v2.0'
await_element = 120
image_name_for_register = '$TEST_IMAGE'
image_name_for_edit = "sahara-itests-ci-vanilla-image"
security_groups = default
[vanilla]
skip_plugin_tests = False
skip_edp_test = False
base_image = "sahara-itests-ci-vanilla-image"
[hdp]
skip_plugin_tests = False
hadoop_version = '1.3.2'
" >> $DASHBOARD_PATH/saharadashboard/tests/configs/config.conf

cd $DASHBOARD_PATH && tox -e uitests
STATUS=$?

glance image-delete $TEST_IMAGE
exit $STATUS
