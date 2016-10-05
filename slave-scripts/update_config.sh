#!/bin/bash -e

source $JENKINS_HOME/credentials

sudo su - zuul -c "cat $WORKSPACE/config/zuul/zuul.conf > /etc/zuul/zuul.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/gearman-logging.conf > /etc/zuul/gearman-logging.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/layout.yaml > /etc/zuul/layout.yaml"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/logging.conf > /etc/zuul/logging.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/openstack_functions.py > /etc/zuul/openstack_functions.py"
sudo systemctl reload zuul.service

sed "s%- net-id: 'LAB_42_PRIVATE_NETWORK_ID'%- net-id: '$LAB_42_PRIVATE_NETWORK_ID'%g" -i $WORKSPACE/config/nodepool/config/sahara.yaml
sed "s%- net-id: 'LAB_43_PRIVATE_NETWORK_ID'%- net-id: '$LAB_43_PRIVATE_NETWORK_ID'%g" -i $WORKSPACE/config/nodepool/config/sahara.yaml
sed "s%apikey=JENKINS_API_KEY%apikey=$JENKINS_API_KEY%g" -i $WORKSPACE/config/nodepool/config/secure.conf
sed "s%credentials=CREDENTIALS_ID%credentials=$CREDENTIALS_ID%g" -i $WORKSPACE/config/nodepool/config/secure.conf
sudo su - nodepool -c "cat $WORKSPACE/config/nodepool/config/sahara.yaml > /etc/nodepool/nodepool.yaml"
sudo su - nodepool -c "cat $WORKSPACE/config/nodepool/config/secure.conf > /etc/nodepool/secure.conf"

sed "s%MYSQL_PASS=MYSQL_ROOT_PASSWORD%MYSQL_PASS=$MYSQL_ROOT_PASSWORD%g" -i $WORKSPACE/config/nodepool/scripts/prepare_node.sh
sed "s%JENKINS_PUBLIC_KEY%$JENKINS_PUBLIC_KEY%g" -i $WORKSPACE/config/nodepool/scripts/prepare_node.sh

NODEPOOL_SCRIPTS_DIR=$(sudo su - -c "cat /etc/nodepool/nodepool.yaml | grep 'script-dir:'" | awk '{print $2}')
cp $WORKSPACE/config/nodepool/scripts/* $NODEPOOL_SCRIPTS_DIR

cp $WORKSPACE/slave-scripts/update_pool.sh /opt/ci/files/
