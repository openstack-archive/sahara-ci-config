#!/bin/bash
set +x

. /home/ubuntu/sahara-ci-config/system-configs/functions.sh

default_path=/opt/ci
projects=( "openstack-infra/nodepool" "openstack-infra/zuul" "openstack-infra/jenkins-job-builder" )

for project in "${projects[@]}"
do
    project_dir=$default_path/$(basename $project)
    if [ "$project" == "jenkins-job-builder" ]; then
        project_dir=$default_path/jenkins_jobs
    fi
    mkdir $project_conf_dir
    touch $project_conf_dir/$(basename $project).conf
    clone $project $project_dir
    install_to_venv $project_dir
    if [ $project == "zuul" ]; then
        mkdir -p /var/lib/zuul/
        touch /var/lib/zuul/times
        touch /var/log/zuul/gearman-server
        sudo chown -R $project:$project /var/lib/$project
    fi
    sudo mkdir -p /var/log/$project
    sudo chown -R $project:$project /etc/$project
    sudo chown -R $project:$project /var/log/$project
    sudo chown -R $project:$project /opt/ci/$project
done

# prepare apache

cp /home/ubuntu/sahara-ci-config/system-configs/sites-available/* /etc/apache2/sites-available/

for host in $(/etc/apache2/sites-available/*)
do
    sudo a2ensite $(basename $host)
done

sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_connect
sudo a2enmod rewrite

sudo systemctl restart apache2.service

# prepare jenkins

echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jenkins

#prepare jenkins-jobs-builder
mkdir /etc/jenkins_jobs
cp /home/ubuntu/sahara-ci-config/config/jjb/* /etc/jenkins_jobs
sed "s%user=USER%user=$JJB_USER%g" -i /etc/jenkins_jobs/jenkins_jobs.ini
sed "s%password=PASSWORD%password=$JJB_PASSWORD%g" -i /etc/jenkins_jobs/jenkins_jobs.ini
sudo chown -R jenkins:jenkins /etc/jenkins_jobs/
sudo ln -s /opt/ci/jenkins-job-builder/venv/bin/jenkins-jobs /usr/local/bin/jenkins-jobs

# prepare zuul

# need trigger update-config job
sudo mkdir -p /var/www/zuul
sudo bash /opt/ci/zuul/etc/status/fetch-dependencies.sh
sudo cp -r /opt/ci/zuul/etc/status/public_html/* /var/www/zuul
sudo chown -R zuul:zuul /var/www/zuul

sudo ln -s /opt/ci/zuul/venv/bin/zuul /usr/sbin/zuul-client

#prepare nodepool
mkdir -p /opt/ci/files/nodepool-scripts
sudo cp /home/ubuntu/sahara-ci-config/config/nodepool/scripts/* /opt/ci/files/nodepool-scripts
mkdir -p /var/run/nodepool/
sudo chown jenkins:jenkins /opt/ci/files/update_pool.sh
sudo chown -R nodepool:nodepool /var/run/nodepool/
sudo chown -R nodepool:nodepool /opt/ci/files/nodepool-scripts

sudo mysql -uroot -Bse "CREATE USER 'nodepool'@'localhost'"
sudo mysql -uroot -Bse "GRANT ALL PRIVILEGES ON *.* TO 'nodepool'@'localhost' WITH GRANT OPTION"
sudo mysql -uroot -Bse "FLUSH PRIVILEGES"
sudo mysql -unodepool -Bse "create database nodepool"

sudo ln -s /opt/ci/nodepool/venv/bin/nodepool /usr/sbin/nodepool-client

cp /home/ubuntu/sahara-ci-config/system-configs/systemd/* /lib/systemd/system/
