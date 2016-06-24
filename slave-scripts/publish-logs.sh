#!/bin/bash -e

dir_name=$(date '+%d-%b-%Y')
lab=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

echo "Moving logs to the https://sahara-ci-reports.mirantis.com"
rsync -e "ssh -i /home/jenkins/.ssh/rsync_key" -avz /opt/stack/logs/ ubuntu@172.18.180.78:/var/www/html/devstack/$lab/$dir_name
