#!/bin/bash -e

# Example of $JENKINS_HOME/credentials:
#OPENSTACK_HOST_LAB_42=172.18.168.42
#OPENSTACK_HOST_LAB_43=172.18.168.43
#REPORT_HOST_SSH_USERNAME=user
source $JENKINS_HOME/credentials

dir_name=$(date '+%d-%b-%Y')
mkdir $dir_name

echo "Moving logs from $OPENSTACK_HOST_LAB_42 to the https://sahara-ci-reports.vm.mirantis.net"
rsync -e "ssh -i .ssh/rsync_key" -a /opt/stack/logs/ $REPORT_HOST_SSH_USERNAME@sahara-ci-reports.vm.mirantis.net:/var/www/html/devstack/42/$dir_name
rm $dir_name/*

echo "Moving logs from $OPENSTACK_HOST_LAB_43 to the https://sahara-ci-reports.vm.mirantis.net"
rsync -e "ssh -i .ssh/rsync_key" -a /opt/stack/logs/ $REPORT_HOST_SSH_USERNAME@sahara-ci-reports.vm.mirantis.net:/var/www/html/devstack/43/$dir_name

rm -rf $dir_name
