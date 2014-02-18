#!/bin/bash

source $JENKINS_HOME/credentials
sed "s%-CI_TENANT_ID-%$CI_TENANT_ID%g" -i $WORKSPACE/config/zuul/openstack_functions.py
sed "s%-CI_TENANT_ID-%$CI_TENANT_ID%g" -i $WORKSPACE/scripts/credentials.conf

sudo su - jenkins -c "cat $WORKSPACE/scripts/credentials.conf > /opt/ci/jenkins-jobs/credentials.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/zuul.conf > /etc/zuul/zuul.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/gearman-logging.conf > /etc/zuul/gearman-logging.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/layout.yaml > /etc/zuul/layout.yaml"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/logging.conf > /etc/zuul/logging.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/openstack_functions.py > /etc/zuul/openstack_functions.py"
sudo service zuul reload

sed "s%- net-id: 'PRIVATE_NETWORK_ID'%- net-id: '$PRIVATE_NETWORK_ID'%g" -i $WORKSPACE/config/nodepool/savanna.yaml
sed "s%apikey: JENKINS_API_KEY%apikey: $JENKINS_API_KEY%g" -i $WORKSPACE/config/nodepool/savanna.yaml
sed "s%credentials-id: CREDENTIALS_ID%credentials-id: $CREDENTIALS_ID%g" -i $WORKSPACE/config/nodepool/savanna.yaml
sudo su - nodepool -c "cat $WORKSPACE/config/nodepool/savanna.yaml > /etc/nodepool/nodepool.yaml"

sed "s%MYSQL_PASS=MYSQL_ROOT_PASSWORD%MYSQL_PASS=$MYSQL_ROOT_PASSWORD%g" -i $WORKSPACE/config/infra-config/prepare_node.sh
sed "s%JENKINS_PUBLIC_KEY%$JENKINS_PUBLIC_KEY%g" -i $WORKSPACE/config/infra-config/prepare_node.sh
cp $WORKSPACE/config/infra-config/* /opt/ci/config/modules/openstack_project/files/nodepool/scripts/
