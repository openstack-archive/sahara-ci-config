#!/bin/bash -e

sudo iptables -F
sudo pip install $WORKSPACE

SAVANNA_LOG=/tmp/sahara.log

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

#rm -f /tmp/savanna-server.db
rm -rf /tmp/cache

mysql -usavanna-citest -psavanna-citest -Bse "DROP DATABASE IF EXISTS savanna"
mysql -usavanna-citest -psavanna-citest -Bse "create database savanna"

BUILD_ID=dontKill

#screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16
screen -dmS display sudo X

export DISPLAY=:0

mkdir ~/.pip
touch ~/.pip/pip.conf

echo "
[global]
timeout = 60
index-url = https://sahara.mirantis.com/pypi/
extra-index-url = http://pypi.openstack.org/openstack/
download-cache = /home/jenkins/.pip/cache/
[install]
use-mirrors = true
" > ~/.pip/pip.conf

echo "
[easy_install]
index_url = https://sahara.mirantis.com/pypi/
" > ~/.pydistutils.cfg

cd $HOME
rm -rf sahara

echo "
[DEFAULT]

os_auth_host=172.18.168.42
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_floating_ips=true
use_neutron=true
[database]
connection=mysql://savanna-citest:savanna-citest@localhost/savanna?charset=utf8"  > sahara.conf

git clone https://github.com/openstack/sahara
cd sahara
sudo pip install .
export PIP_USE_MIRRORS=True
sahara-db-manage --config-file $HOME/sahara.conf upgrade head
screen -dmS sahara /bin/bash -c "PYTHONUNBUFFERED=1 sahara-all --config-file $HOME/sahara.conf -d --log-file /tmp/sahara.log"

i=0
while true
do
        let "i=$i+1"
        if [ "$i" -gt "120" ]; then
                echo "project does not start" && FAILURE=1 && break
        fi
        if [ ! -f $SAVANNA_LOG ]; then
                sleep 10
        else
                echo "project is started" && FAILURE=0 && break
        fi
done

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
keystone_url = 'http://172.18.168.42:5000/v2.0'
await_element = 120
image_name_for_register = 'ubuntu-12.04'
image_name_for_edit = "savanna-itests-ci-vanilla-image"
[vanilla]
skip_plugin_tests = False
skip_edp_test = False
base_image = "savanna-itests-ci-vanilla-image"
[hdp]
skip_plugin_tests = False
hadoop_version = '1.3.2'
" >> $WORKSPACE/saharadashboard/tests/configs/config.conf

cd $WORKSPACE && tox -e uitests
