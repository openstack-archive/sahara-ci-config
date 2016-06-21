#!/bin/bash -xe

wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

APT_PACKAGES="git python-dev gcc make jenkins"
PIP_PACKAGES+=" virtualenv"

sudo apt-get update
sudo apt-get install -y $APT_PACKAGES

sudo pip install -U $PIP_PACKAGES

mkdir /opt/ci/files

# create users
projects=( "nodepool" "zuul" )
for project in "${projects[@]}"
do
    sudo useradd -d /home/$project -G sudo -s /bin/bash -m $project
#    echo "$project ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$project
    sudo mkdir /home/$project/.ssh
done

# install jenkins plugins
while read plugin
do
    wget http://updates.jenkins-ci.org/latest/$plugin -P /var/lib/jenkins/plugins
done < /home/ubuntu/sahara-ci-config/system-configs/jenkins-plugins

sudo service jenkins restart

# download plugins
wget http://updates.jenkins-ci.org/latest/git.hpi -P /var/lib/jenkins/plugins

mkdir /etc/jenkins_jobs
cp /home/ubuntu/sahara-ci-config/config/jjb/* /etc/jenkins_jobs
sed "s%user=USER%user=$JJB_USER%g" -i /etc/jenkins_jobs/jenkins_jobs.ini
sed "s%password=PASSWORD%password=$JJB_PASSWORD%g" -i /etc/jenkins_jobs/jenkins_jobs.ini
