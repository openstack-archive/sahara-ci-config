#!/bin/bash

set +x

wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

APT_PACKAGES="git python-dev gcc make jenkins python-pip apache2 unzip mysql-server libssl-dev"
PIP_PACKAGES+=" virtualenv"

sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password '
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password '

sudo apt update
sudo apt install -y $APT_PACKAGES

sudo pip install -U $PIP_PACKAGES

mkdir -p /opt/ci/files

# create users
projects=( "nodepool" "zuul" )
for project in "${projects[@]}"
do
    sudo useradd -d /home/$project -G sudo -s /bin/bash -m $project
    sudo mkdir /home/$project/.ssh
    sudo chown -R $project:$project /home/$project
done

bash /home/ubuntu/sahara-ci-config/system-configs/install_projects.sh

# install jenkins plugins
while read plugin
do
    wget http://updates.jenkins-ci.org/latest/$plugin -P /var/lib/jenkins/plugins
done < /home/ubuntu/sahara-ci-config/system-configs/jenkins-plugins

sudo service jenkins restart
