#!/bin/bash -xe

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
