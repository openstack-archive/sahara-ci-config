#!/bin/bash

source $JENKINS_HOME/credentials
sudo su - zuul -c "cat $WORKSPACE/config/zuul/zuul.conf > /etc/zuul/zuul.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/gearman-logging.conf > /etc/zuul/gearman-logging.conf"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/layout.yaml > /etc/zuul/layout.yaml"
sudo su - zuul -c "cat $WORKSPACE/config/zuul/logging.conf > /etc/zuul/logging.conf"
sudo service zuul reload

sed "s%apikey: JENKINS_API_KEY%apikey: $JENKINS_API_KEY%g" -i $WORKSPACE/config/nodepool/savanna.yaml
sed "s%credentials-id: CREDENTIALS_ID%credentials-id: $CREDENTIALS_ID%g" -i $WORKSPACE/config/nodepool/savanna.yaml
sudo su - nodepool -c "cat $WORKSPACE/config/nodepool/savanna.yaml > /etc/nodepool/nodepool.yaml"
