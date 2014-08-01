#!/bin/bash -e

. ./common-scripts.sh

check_openstack_host

sudo iptables -F
sudo pip install $WORKSPACE

create_database

#screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16
screen -dmS display sudo X
export DISPLAY=:0
#enable_pypi

cd $HOME
write_sahara_main_conf sahara.conf
rm -rf sahara
git clone https://github.com/openstack/sahara
cd sahara
sudo pip install .
start_sahara $HOME/sahara.conf

if [ "$FAILURE" != 0 ]; then
    exit 1
fi

sudo service apache2 restart
sleep 20

echo "
[common]
base_url = 'http://localhost'
user = 'ci-user'
password = 'nova'
tenant = 'ci'
flavor = 'qa-flavor'
neutron_management_network = 'private'
floationg_ip_pool = 'public'
keystone_url = 'http://$OPENSTACK_HOST:5000/v2.0'
await_element = 120
image_name_for_register = 'ubuntu-12.04'
image_name_for_edit = "sahara-itests-ci-vanilla-image"
[vanilla]
skip_plugin_tests = False
skip_edp_test = False
base_image = "sahara-itests-ci-vanilla-image"
[hdp]
skip_plugin_tests = False
hadoop_version = '1.3.2'
" >> $WORKSPACE/saharadashboard/tests/configs/config.conf

cd $WORKSPACE && tox -e uitests
