#!/bin/bash
set +x

. /home/ubuntu/sahara-ci-config/system-configs/functions.sh

default_path=/opt/ci
projects=( "openstack-infra/nodepool" "openstack-infra/zuul" "openstack-infra/jenkins-job-builder" )

for project in "${projects[@]}"
do
    project_dir=$default_path/$(basename $project)
    project_conf_dir=/etc/$(basename $project)
    if [ "$project" == "jenkins-job-builder" ]; then
        project_conf_dir=/etc/jenkins_jobs
    fi
    mkdir $project_conf_dir
    touch $project_conf_dir/$(basename $project).conf
    clone $project $project_dir
    install_to_venv $project_dir
done

# prepare apache

cp /home/ubuntu/sahara-ci-config/system-configs/sites-available/* /etc/apache2/sites-available/

for host in `ls /etc/apache2/sites-available/`
do
    sudo a2ensite $host
done

sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_connect
sudo a2enmod rewrite

sudo systemctl restart apache2.service

# prepare jenkins

echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jenkins
sudo ln -s /opt/ci/jenkins-job-builder/venv/bin/jenkins-jobs /usr/local/sbin/jenkins-jobs

# prepare zuul

#need trigger update-config job
sudo mkdir -p /var/www/zuul
sudo bash /opt/ci/zuul/etc/status/fetch-dependencies.sh
sudo cp -r /opt/ci/zuul/etc/status/public_html/* /var/www/zuul
sudo chown -R zuul:zuul /var/www/zuul

#prepare nodepool
cp  /home/ubuntu/sahara-ci-config/config/nodepool/config/* /etc/nodepool
mkdir -p /opt/ci/files/nodepool-scripts
mkdir /var/log/nodepool
sudo chown -R nodepool:nodepool /opt/ci/files/nodepool-scripts
sudo chown -R nodepool:nodepool /var/log/nodepool

sudo mysql -uroot -Bse "CREATE USER 'nodepool'@'localhost'"
sudo mysql -uroot -Bse "GRANT ALL PRIVILEGES ON *.* TO 'nodepool'@'localhost' WITH GRANT OPTION"
sudo mysql -uroot -Bse "FLUSH PRIVILEGES"
sudo mysql -unodepool -Bse "create database nodepool"


#prepare jenkins-jobs-builder
mkdir /etc/jenkins_jobs
cp /home/ubuntu/sahara-ci-config/config/jjb/* /etc/jenkins_jobs
sed "s%user=USER%user=$JJB_USER%g" -i /etc/jenkins_jobs/jenkins_jobs.ini
sed "s%password=PASSWORD%password=$JJB_PASSWORD%g" -i /etc/jenkins_jobs/jenkins_jobs.ini

cp /home/ubuntu/sahara-ci-config/system-configs/systemd/* /lib/systemd/system/
