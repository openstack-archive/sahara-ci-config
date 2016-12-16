#!/bin/bash -e

dir_name=$(date '+%d-%b-%Y')
job_type=$(echo $JOB_NAME | awk -F '-' '{print $1}')
lab=$(echo $JOB_NAME | awk -F '-' '{ print $4 }')

echo "Moving $job_type logs to the https://sahara-ci-reports.mirantis.com"
if [ "$job_type" == "nightly" ]; then
rsync -e "ssh -i /home/jenkins/.ssh/rsync_key" -avz /opt/stack/logs/ ubuntu@172.18.180.78:/var/www/html/devstack//$job_type/$lab/$dir_name;
else
rsync -e "ssh -i /home/jenkins/.ssh/rsync_key" -avz /opt/stack/logs/ ubuntu@172.18.180.78:/var/www/html/devstack/$lab/$dir_name;
fi