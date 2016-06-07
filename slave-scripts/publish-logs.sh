#!/bin/bash -e

source $JENKINS_HOME/credentials

dir_name=$(date '+%d-%b-%Y')
mkdir $dir_name

sshpass -p $LAB_42_SSH_PASSWORD scp -o StrictHostKeyChecking=no $LAB_42_SSH_USERNAME@$OPENSTACK_HOST_LAB_42:/opt/stack/logs/* $dir_name
sshpass -p $REPORT_HOST_SSH_PASSWORD scp -o StrictHostKeyChecking=no -r $dir_name $REPORT_HOST_SSH_USERNAME@$REPORT_HOST:/var/www/html/devstack/42
rm $dir_name/*

sshpass -p $LAB_43_SSH_PASSWORD scp -o StrictHostKeyChecking=no $LAB_43_SSH_USERNAME@$OPENSTACK_HOST_LAB_43:/opt/stack/logs/* $dir_name
sshpass -p $REPORT_HOST_SSH_PASSWORD scp -o StrictHostKeyChecking=no -r $dir_name $REPORT_HOST_SSH_USERNAME@$REPORT_HOST:/var/www/html/devstack/43

rm -rf $dir_name
