#!/bin/bash

set +x

wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

APT_PACKAGES="git python-dev gcc make jenkins python-pip apache2 unzip"
PIP_PACKAGES+=" virtualenv"

sudo apt update
sudo apt install -y $APT_PACKAGES

sudo pip install -U $PIP_PACKAGES

mkdir -p /opt/ci/files

bash /home/ubuntu/sahara-ci-config/system-configs/install_projects.sh

# create users
projects=( "nodepool" "zuul" )
for project in "${projects[@]}"
do
    sudo useradd -d /home/$project -G sudo -s /bin/bash -m $project
    sudo mkdir /home/$project/.ssh
    sudo chown -R $project:$project /etc/$project
    if [ $project == "zuul" ]; then
        mkdir -p /var/lib/zuul/
	mkdir -p /var/log/zuul/
	touch /var/lib/zuul/times
	touch /var/log/zuul/gearman-server
        sudo chown -R $project:$project /var/lib/zuul/
	sudo chown -R $project:$project /var/log/zuul/
    fi
done

# install jenkins plugins
while read plugin
do
    wget http://updates.jenkins-ci.org/latest/$plugin -P /var/lib/jenkins/plugins
done < /home/ubuntu/sahara-ci-config/system-configs/jenkins-plugins

sudo service jenkins restart
