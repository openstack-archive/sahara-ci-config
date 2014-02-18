#!/bin/bash

#this is to fix bug with testtools==0.9.35
#sed 's/testtools>=0.9.32/testtools==0.9.34/' -i test-requirements.txt

JOB_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')                                 
TIMEOUT=60
                                                                                
if [ $JOB_TYPE == 'heat' ]                                                      
then                                                                            
    HEAT_JOB=True
    HDP_IMAGE=savanna-itests-ci-hdp-image-jdk-iptables-off
    VANILLA_IMAGE=savanna-itests-ci-vanilla-image
    SSH_USERNAME=ec2-user
    echo "Heat detected"
    JOB_TYPE=$(echo $JOB_NAME | awk -F '-' '{ print $5 }')                             
    if [ $JOB_TYPE == 'hdp'  ]                                                  
    then                                                                        
        HDP_JOB=True
        echo "HDP detected"
    else                                                                        
        VANILLA_JOB=True
        echo "Vanilla detected"
    fi                                                                          
else                                                                            
    if [ $JOB_TYPE == 'hdp' ]                                                   
    then                                                                        
       HDP_JOB=True
       HDP_IMAGE=savanna-itests-ci-hdp-image-jdk-iptables-off
       echo "HDP detected"
    fi
    if [ $JOB_TYPE == 'vanilla' ]
    then
       VANILLA_JOB=True 
       VANILLA_IMAGE=savanna-itests-ci-vanilla-image
       echo "Vanilla detected"
    fi
    if [ $JOB_TYPE == 'idh' ]
    then
       IDH_JOB=True 
       TIMEOUT=120
       echo "IDH detected"
    fi    
fi 

export PYTHONUNBUFFERED=1

cd $WORKSPACE

TOX_LOG=$WORKSPACE/.tox/venv/log/venv-1.log 
TMP_LOG=/tmp/tox.log
LOG_FILE=/tmp/tox_log.log

SCR_CHECK=$(ps aux | grep screen | grep savanna)
if [ -n "$SCR_CHECK" ]; then
     screen -S savanna-api -X quit
fi

rm -f /tmp/savanna-server.db
rm -rf /tmp/cache
rm -f $LOG_FILE

mysql -usavanna-citest -psavanna-citest -Bse "DROP DATABASE IF EXISTS savanna"
mysql -usavanna-citest -psavanna-citest -Bse "create database savanna"

BUILD_ID=dontKill

#sudo pip install tox
mkdir /tmp/cache

export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

infrastructure_engine=heat

echo "[DEFAULT]
" >> etc/savanna/savanna.conf

if [ $HEAT_JOB ]
then
    echo "infrastructure_engine=heat
    " >> etc/savanna/savanna.conf
fi

echo "
os_auth_host=172.18.168.42
os_auth_port=5000
os_admin_username=ci-user
os_admin_password=nova
os_admin_tenant_name=ci
use_neutron=true
plugins=vanilla,hdp,idh
[cluster_node]
[sqlalchemy]
[plugin:vanilla]
plugin_class=savanna.plugins.vanilla.plugin:VanillaProvider
[plugin:hdp]
plugin_class=savanna.plugins.hdp.ambariplugin:AmbariPlugin
[database]
connection=mysql://savanna-citest:savanna-citest@localhost/savanna?charset=utf8" >> etc/savanna/savanna.conf
#touch ~/.pip/pip.conf

#echo "
#[global] 
#timeout = 60
#index-url = http://savanna-ci.vm.mirantis.net/pypi/savanna/
#extra-index-url = https://pypi.python.org/simple/
#download-cache = /home/ubuntu/.pip/cache/
#[install]
#use-mirrors = true
#find-links = http://savanna-ci.vm.mirantis.net:8181/simple/
#" > ~/.pip/pip.conf
tox -evenv -- savanna-db-manage --config-file etc/savanna/savanna.conf upgrade head

screen -dmS savanna-api /bin/bash -c "PYTHONUNBUFFERED=1 tox -evenv -- savanna-api --config-file etc/savanna/savanna.conf -d --log-file log.txt | tee /tmp/tox-log.txt"


export ADDR=`ifconfig eth0| awk -F ' *|:' '/inet addr/{print $4}'`

echo "[COMMON]
OS_USERNAME = 'ci-user'
OS_PASSWORD = 'nova'
OS_TENANT_NAME = 'ci'
OS_AUTH_URL = 'http://172.18.168.42:5000/v2.0'
SAVANNA_HOST = '$ADDR'
FLAVOR_ID = '20'
CLUSTER_CREATION_TIMEOUT = $TIMEOUT
CLUSTER_NAME = 'ci-$BUILD_NUMBER-$ZUUL_CHANGE-$ZUUL_PATCHSET'
FLOATING_IP_POOL = 'public'
NEUTRON_ENABLED = True
INTERNAL_NEUTRON_NETWORK = 'private'
$COMMON_PARAMS
" >> $WORKSPACE/savanna/tests/integration/configs/itest.conf

echo "[VANILLA]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$VANILLA_IMAGE'
$VANILLA_PARAMS
" >> $WORKSPACE/savanna/tests/integration/configs/itest.conf

echo "[HDP]
SSH_USERNAME = '$SSH_USERNAME'
IMAGE_NAME = '$HDP_IMAGE'
SKIP_ALL_TESTS_FOR_PLUGIN = False
$HDP_PARAMS
" >> $WORKSPACE/savanna/tests/integration/configs/itest.conf

echo "[IDH]
IMAGE_ID = 'c0492fb9-a6b6-4d78-867b-b5be12fe6611'
IDH_REPO_URL = 'http://172.18.87.221/mirror/inteldistribution-2.5.1'
OS_REPO_URL = 'http://172.18.87.221/mirror/centos/base/'
SSH_USERNAME = 'cloud-user'
MANAGER_FLAVOR_ID = '3'
" >> $WORKSPACE/savanna/tests/integration/configs/itest.conf

touch $TMP_LOG
i=0

while true
do
        let "i=$i+1"
        diff $TOX_LOG $TMP_LOG >> $LOG_FILE
        cp -f $TOX_LOG $TMP_LOG
        if [ "$i" -gt "240" ]; then
                cat $LOG_FILE
                echo "project does not start" && FAILURE=1 && break
        fi
        if [ ! -f $WORKSPACE/log.txt ]; then
                sleep 10
        else
                echo "project is started" && FAILURE=0 && break
        fi
done

if [ "$FAILURE" = 0 ]; then
   
    export PYTHONUNBUFFERED=1
   
    cd $WORKSPACE
    if [ $HDP_JOB ]
    then
        tox -e integration -- hdp
        STATUS=`echo $?`               
    fi                               

    if [ $VANILLA_JOB ]
    then
        tox -e integration -- vanilla
        STATUS=`echo $?`
    fi
    
    if [ $IDH_JOB ]
    then
        tox -e integration -- idh
        STATUS=`echo $?`
    fi    
    
fi

echo "-----------Python integration env-----------"
cd $WORKSPACE && .tox/integration/bin/pip freeze

screen -S savanna-api -X quit

echo "-----------Python savanna env-----------"
cd $WORKSPACE && .tox/venv/bin/pip freeze

echo "-----------Savanna Log------------"
cat $WORKSPACE/log.txt
rm -rf /tmp/workspace/
rm -rf /tmp/cache/

echo "-----------Tox log-----------"
cat /tmp/tox-log.txt
rm -f /tmp/tox-log.txt

rm -f /tmp/savanna-server.db
rm $TMP_LOG
rm -f $LOG_FILE

if [ "$FAILURE" != 0 ]; then
    exit 1
fi

if [[ "$STATUS" != 0 ]]        
then                               
    exit 1                    
fi
