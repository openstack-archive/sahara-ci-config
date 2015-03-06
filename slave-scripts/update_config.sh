#!/bin/bash

source $JENKINS_HOME/credentials
sed "s%-NEUTRON_LAB_TENANT_ID-%$NEUTRON_LAB_TENANT_ID%g" -i $WORKSPACE/config/zuul/openstack_functions.py
sed "s%-NOVA_NET_LAB_TENANT_ID-%$NOVA_NET_LAB_TENANT_ID%g" -i $WORKSPACE/config/zuul/openstack_functions.py

sudo su - jenkins -c "cat $WORKSPACE/slave-scripts/credentials.conf > /etc/jenkins_jobs/credentials.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/zuul.conf > /etc/zuul/zuul.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/gearman-logging.conf > /etc/zuul/gearman-logging.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/layout.yaml > /etc/zuul/layout.yaml"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/logging.conf > /etc/zuul/logging.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/openstack_functions.py > /etc/zuul/openstack_functions.py"
sudo service zuul reload

sed "s%- net-id: 'NEUTRON_LAB_PRIVATE_NETWORK_ID'%- net-id: '$NEUTRON_LAB_PRIVATE_NETWORK_ID'%g" -i $WORKSPACE/config/nodepool/sahara.yaml
sed "s%- net-id: 'NOVA_NET_LAB_PRIVATE_NETWORK_ID'%- net-id: '$NOVA_NET_LAB_PRIVATE_NETWORK_ID'%g" -i $WORKSPACE/config/nodepool/sahara.yaml
sed "s%apikey: JENKINS_API_KEY%apikey: $JENKINS_API_KEY%g" -i $WORKSPACE/config/nodepool/sahara.yaml
sed "s%credentials-id: CREDENTIALS_ID%credentials-id: $CREDENTIALS_ID%g" -i $WORKSPACE/config/nodepool/sahara.yaml
sudo su - nodepool -c "cat $WORKSPACE/config/nodepool/sahara.yaml > /etc/nodepool/nodepool.yaml"

sed "s%MYSQL_PASS=MYSQL_ROOT_PASSWORD%MYSQL_PASS=$MYSQL_ROOT_PASSWORD%g" -i $WORKSPACE/config/nodepool/scripts/prepare_node.sh
sed "s%JENKINS_PUBLIC_KEY%$JENKINS_PUBLIC_KEY%g" -i $WORKSPACE/config/nodepool/scripts/prepare_node.sh

NODEPOOL_SCRIPTS_DIR=$(sudo su - -c "cat /etc/nodepool/nodepool.yaml | grep 'script-dir:'" | awk '{print $2}')
cp $WORKSPACE/config/nodepool/scripts/* $NODEPOOL_SCRIPTS_DIR
