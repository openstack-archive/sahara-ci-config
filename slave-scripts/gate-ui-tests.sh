#!/bin/bash -e

sudo iptables -F
sudo pip install $WORKSPACE

NETWORK=`ifconfig eth0 | awk -F ' *|:' '/inet addr/{print $4}' | awk -F . '{print $2}'`
if [ "$NETWORK" == "0" ]; then
    OPENSTACK_HOST="172.18.168.42"
else
    OPENSTACK_HOST="172.18.168.43"
fi

SAHARA_LOG=/tmp/sahara.log

SCR_CHECK=$(ps aux | grep screen | grep display)
if [ -n "$SCR_CHECK" ]; then
     screen -S display -X quit
fi

screen -S sahara -X quit

#DETECT_XVFB=$(ps aux | grep Xvfb | grep -v grep)
DETECT_XVFB=$(ps aux | grep X | grep -v grep)
if [ -n "$DETECT_XVFB" ]; then
     sudo killall X
fi

ps aux | grep X

#rm -f /tmp/sahara-server.db
rm -rf /tmp/cache

mysql -usahara-citest -psahara-citest -Bse "DROP DATABASE IF EXISTS sahara"
mysql -usahara-citest -psahara-citest -Bse "create database sahara"

BUILD_ID=dontKill

#screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16
screen -dmS display sudo X

export DISPLAY=:0

#mkdir ~/.pip
#touch ~/.pip/pip.conf

#echo "
#[global]
#timeout = 60
#index-url = https://sahara.mirantis.com/pypi/
#extra-index-url = http://pypi.openstack.org/openstack/
#download-cache = /home/jenkins/.pip/cache/
#[install]
#use-mirrors = true
#" > ~/.pip/pip.conf

#echo "
#[easy_install]
#index_url = https://sahara.mirantis.com/pypi/
#" > ~/.pydistutils.cfg

cd $HOME

echo "
[DEFAULT]

os_auth_host=$OPENSTACK_HOST
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_floating_ips=true
use_neutron=true
[database]
connection=mysql://sahara-citest:sahara-citest@localhost/sahara?charset=utf8
[keystone_authtoken]
auth_uri=http://$OPENSTACK_HOST:5000/v2.0/
identity_uri=http://$OPENSTACK_HOST:35357/
admin_user=ci-user
admin_password=nova
admin_tenant_name=ci"  > sahara.conf

rm -rf sahara
git clone https://github.com/openstack/sahara
cd sahara
sudo pip install .
export PIP_USE_MIRRORS=True
sahara-db-manage --config-file $HOME/sahara.conf upgrade head
screen -dmS sahara /bin/bash -c "PYTHONUNBUFFERED=1 sahara-all --config-file $HOME/sahara.conf -d --log-file /tmp/sahara.log"

API_RESPONDING_TIMEOUT=30
FAILURE=0

if ! timeout ${API_RESPONDING_TIMEOUT} sh -c "while ! curl -s http://127.0.0.1:8386/v1.1/ 2>/dev/null | grep -q 'Authentication required' ; do sleep 1; done"; then
    echo "Sahara API failed to respond within ${API_RESPONDING_TIMEOUT} seconds"
    FAILURE=1
fi

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
