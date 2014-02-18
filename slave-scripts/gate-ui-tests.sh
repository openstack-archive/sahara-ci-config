#!/bin/bash -e

sudo iptables -F
sudo pip install $WORKSPACE

SAVANNA_LOG=/tmp/savanna.log 

SCR_CHECK=$(ps aux | grep screen | grep display)
if [ -n "$SCR_CHECK" ]; then
     screen -S display -X quit
fi

screen -S savanna -X quit

DETECT_XVFB=$(ps aux | grep Xvfb | grep -v grep)
if [ -n "$DETECT_XVFB" ]; then
     sudo killall Xvfb
fi

ps aux | grep Xvfb

rm -f /tmp/savanna-server.db
rm -rf /tmp/cache

mysql -usavanna-citest -psavanna-citest -Bse "DROP DATABASE IF EXISTS savanna"
mysql -usavanna-citest -psavanna-citest -Bse "create database savanna"

BUILD_ID=dontKill

screen -dmS display sudo Xvfb -fp /usr/share/fonts/X11/misc/ :22 -screen 0 1024x768x16

export DISPLAY=:22

cd $HOME
rm -rf savanna

echo "
[DEFAULT]

os_auth_host=172.18.168.42
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_floating_ips=true
use_neutron=true

plugins=vanilla,hdp


[plugin:vanilla]
plugin_class=savanna.plugins.vanilla.plugin:VanillaProvider

[plugin:hdp]
plugin_class=savanna.plugins.hdp.ambariplugin:AmbariPlugin


[database]
connection=mysql://savanna-citest:savanna-citest@localhost/savanna?charset=utf8"  > savanna.conf

git clone https://github.com/openstack/savanna
cd savanna
tox -evenv -- savanna-db-manage --config-file $HOME/savanna.conf upgrade head
screen -dmS savanna /bin/bash -c "PYTHONUNBUFFERED=1 tox -evenv -- savanna-api --config-file $HOME/savanna.conf -d --log-file /tmp/savanna.log"

while true
do
        if [ ! -f $SAVANNA_LOG ]; then
                sleep 10
        else
                echo "project is started" && FAILURE=0 && break
        fi
done

sudo service apache2 restart
sleep 20

echo "
[common]
base_url = 'http://127.0.0.1/horizon'
user = 'ci-user'
password = 'nova'
tenant = 'ci'
flavor = 'm1.small'
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
" >> $WORKSPACE/savannadashboard/tests/configs/config.conf

cd $WORKSPACE && tox -e uitests
