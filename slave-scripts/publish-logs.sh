#!/bin/bash -e

source /home/jenkins/credentials

dir_name=$(date '+%d-%b-%Y')
lab=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

echo "Moving logs to the https://sahara-ci-reports.mirantis.com"
rsync -e "ssh -i ~/.ssh/rsync_key" -a /opt/stack/logs/ ubuntu@172.18.180.78:/var/www/html/devstack/$lab/$dir_name
