#!/bin/bash -e

# Example of $JENKINS_HOME/credentials:
#OPENSTACK_HOST_LAB_42=172.18.168.42
#OPENSTACK_HOST_LAB_43=172.18.168.43
#REPORT_HOST_SSH_USERNAME=user
source /home/jenkins/credentials

dir_name=$(date '+%d-%b-%Y')
lab=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

echo "Moving logs from 172.18.168.$lab to the https://sahara-ci-reports.mirantis.com"
rsync -e "ssh -i .ssh/rsync_key" -a /opt/stack/logs/ $REPORT_HOST_SSH_USERNAME@sahara-ci-reports.mirantis.com:/var/www/html/devstack/$lab/$dir_name
