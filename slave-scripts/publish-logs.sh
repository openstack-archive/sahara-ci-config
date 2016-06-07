#!/bin/bash -e

source $JENKINS_HOME/credentials

dir_name=$(date '+%d-%b-%Y')
mkdir $dir_name

rsync -e "ssh -i .ssh/rsync_key" -a /opt/stack/logs/ $REPORT_HOST_SSH_USERNAME@$REPORT_HOST:/var/www/html/devstack/42/$dir_name
rm $dir_name/*

rsync -e "ssh -i .ssh/rsync_key" -a /opt/stack/logs/ $REPORT_HOST_SSH_USERNAME@$REPORT_HOST:/var/www/html/devstack/43/$dir_name

rm -rf $dir_name
