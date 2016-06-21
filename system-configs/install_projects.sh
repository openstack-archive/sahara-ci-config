#!/bin/bash
set +x

. /home/ubuntu/sahara-ci-config/system-configs/functions.sh

default_path=/opt/ci
projects=( "openstack-infra/nodepool" "openstack-infra/zuul" "openstack-infra/jenkins-job-builder" )

for project in "${projects[@]}"
do
    project_dir=$default_path/$(basename $project)
    project_conf_dir=/etc/$(basename $project)
    mkdir $project_conf_dir
    touch $project_conf_dir/$(basename $project).conf
    clone $project $project_dir
    install_to_venv $project_dir
done

# prepare jenkins

echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jenkins

# prepare zuul

#need trigger update-config job

#prepare nodepool
cp  /home/ubuntu/sahara-ci-config/config/nodepool/config/* /etc/nodepool

#prepare jenkins-jobs-builder
mkdir /etc/jenkins_jobs
cp /home/ubuntu/sahara-ci-config/config/jjb/* /etc/jenkins_jobs
sed "s%user=USER%user=$JJB_USER%g" -i /etc/jenkins_jobs/jenkins_jobs.ini
sed "s%password=PASSWORD%password=$JJB_PASSWORD%g" -i /etc/jenkins_jobs/jenkins_jobs.ini

cp /home/ubuntu/sahara-ci-config/system-config/systemd/* /lib/systemd/system/
