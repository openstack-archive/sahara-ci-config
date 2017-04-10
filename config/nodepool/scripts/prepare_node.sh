#!/bin/bash -xe

# Copyright (C) 2011-2015 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

HOSTNAME=$1
MYSQL_PASS=MYSQL_ROOT_PASSWORD

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o DPkg::Options::="--force-confold" upgrade -y
# APT_PACKAGES variable using for installing packages via apt-get
# PIP_PACKAGES variable using for installing packages via pip
APT_PACKAGES="git python-dev gcc make openjdk-8-jre-headless python-pip mysql-server libpq-dev libmysqlclient-dev"
# RabbitMQ for distributed Sahara mode
APT_PACKAGES+=" rabbitmq-server"
# Required libraries
APT_PACKAGES+=" libxslt1-dev libffi-dev"
# Required packages for DIB
APT_PACKAGES+=" qemu kpartx"
# pep8-trunk job requirements
APT_PACKAGES+=" gettext"
# Glance-client is required for diskimage-integration jobs
PIP_PACKAGES="python-glanceclient"
# Requirements for Sahara
PIP_PACKAGES+=" mysql-python pymysql"
# Requirements for dib-jobs
PIP_PACKAGES+=" python-openstackclient"
PIP_PACKAGES+=" pip==8.1.1 tox"

echo "mysql-server mysql-server/root_password select $MYSQL_PASS" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again select $MYSQL_PASS" | sudo debconf-set-selections

sudo apt-get install -y $APT_PACKAGES
#Remove ccahe because it's useless for single-use nodes and may cause problems
sudo apt-get remove -y ccache
sudo apt-get clean

mysql -uroot -p$MYSQL_PASS -Bse "create database sahara"
mysql -uroot -p$MYSQL_PASS -Bse  "CREATE USER 'sahara-citest'@'localhost' IDENTIFIED BY 'sahara-citest'"
mysql -uroot -p$MYSQL_PASS -Bse "GRANT ALL ON sahara.* TO 'sahara-citest'@'localhost'"
mysql -uroot -p$MYSQL_PASS -Bse "flush privileges"
sudo service mysql stop

sudo pip install -U $PIP_PACKAGES
git clone https://git.openstack.org/openstack/sahara /tmp/sahara
git clone https://git.openstack.org/openstack/sahara-tests /tmp/sahara-tests
git clone https://git.openstack.org/openstack/sahara-ci-config /tmp/sahara-ci-config
sudo pip install -U -r /tmp/sahara/requirements.txt -c https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt
git clone https://git.openstack.org/openstack-infra/project-config /tmp/project-config
sudo mkdir -p /usr/local/jenkins/
sudo mv /tmp/project-config/jenkins/scripts /usr/local/jenkins/slave_scripts
sudo mv /tmp/sahara-ci-config/config/nodepool/scripts/gerrit-git-prep.sh /usr/local/jenkins/slave_scripts
rm -rf /tmp/sahara /tmp/sahara-tests /tmp/project-config /tmp/sahara-ci-config

# create jenkins user
sudo useradd -d /home/jenkins -G sudo -s /bin/bash -m jenkins
echo "jenkins ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/jenkins
sudo mkdir /home/jenkins/.ssh

sudo chown -R jenkins:jenkins /home/jenkins

# create simple openrc file
if [[ "$HOSTNAME" =~ stack-42 ]]; then
   OPENSTACK_HOST="172.18.168.42"
   HOST="c1"
else
   OPENSTACK_HOST="172.18.168.43"
   HOST="c2"
fi
echo "export OS_USERNAME=ci-user
export OS_TENANT_NAME=ci
export OS_PASSWORD=nova
export OPENSTACK_HOST=$OPENSTACK_HOST
export HOST=$HOST
export OS_AUTH_URL=http://$OPENSTACK_HOST:5000/v2.0/
" | sudo tee /home/jenkins/ci_openrc

sudo su - jenkins -c "echo '
JENKINS_PUBLIC_KEY' >> /home/jenkins/.ssh/authorized_keys"
sync
sleep 5
