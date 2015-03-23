#!/bin/bash -xe

# Copyright (C) 2011-2013 OpenStack Foundation
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
SUDO='true'
THIN='true'
MYSQL_PASS=MYSQL_ROOT_PASSWORD

wget https://git.openstack.org/cgit/openstack-infra/system-config/plain/install_puppet.sh
sudo bash -xe install_puppet.sh
sudo git clone https://review.openstack.org/p/openstack-infra/system-config.git \
    /root/config
sudo /bin/bash /root/config/install_modules.sh
sudo puppet apply --modulepath=/root/config/modules:/etc/puppet/modules \
    -e "class {'openstack_project::single_use_slave': sudo => $SUDO, thin => $THIN, enable_unbound => false, }"

sudo mkdir -p /opt/git

# APT_PACKAGES variable using for installing packages via apt-get
# PIP_PACKAGES variable using for installing packages via pip
APT_PACKAGES="mysql-server libpq-dev libmysqlclient-dev"
# RabbitMQ for distributed Sahara mode
APT_PACKAGES+=" rabbitmq-server"
# Required libraries
APT_PACKAGES+=" libxslt1-dev libffi-dev"
# Required packages for DIB
APT_PACKAGES+=" qemu kpartx"
# pep8-trunk job requirements
APT_PACKAGES+=" gettext"
# Glance-client is required for diskimage-integration jobs
PIP_PACKAGES="python-glanceclient==0.16"
# Requirements for Sahara
PIP_PACKAGES+=" mysql-python"
# Requirements for Cloudera plugin
PIP_PACKAGES+=" cm-api"

echo "mysql-server mysql-server/root_password select $MYSQL_PASS" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again select $MYSQL_PASS" | sudo debconf-set-selections

sudo apt-get install -y $APT_PACKAGES
#Remove ccahe because it's useless for single-use nodes and may cause problems
sudo apt-get remove -y ccache

mysql -uroot -p$MYSQL_PASS -Bse "create database sahara"
mysql -uroot -p$MYSQL_PASS -Bse  "CREATE USER 'sahara-citest'@'localhost' IDENTIFIED BY 'sahara-citest'"
mysql -uroot -p$MYSQL_PASS -Bse "GRANT ALL ON sahara.* TO 'sahara-citest'@'localhost'"
mysql -uroot -p$MYSQL_PASS -Bse "flush privileges"
sudo service mysql stop

sudo pip install $PIP_PACKAGES
cd /tmp && git clone https://git.openstack.org/openstack/sahara
cd sahara && sudo pip install -U -r requirements.txt
cd /home/jenkins && rm -rf /tmp/sahara

# Java tarbal for diskimage jobs
sudo wget --no-check-certificate --no-cookies --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
   -P /home/jenkins http://download.oracle.com/otn-pub/java/jdk/7u51-b13/jdk-7u51-linux-x64.tar.gz

pushd /home/jenkins
sudo git clone https://git.openstack.org/openstack/tempest
# temporary comment
#pushd tempest && sudo pip install -U -r requirements.txt && popd
sudo chown -R jenkins:jenkins /home/jenkins
popd

# create simple openrc file
if [[ "$HOSTNAME" =~ neutron ]]; then
   OPENSTACK_HOST="172.18.168.42"
   HOST="c1"
   USE_NEUTRON=true
else
   OPENSTACK_HOST="172.18.168.43"
   HOST="c2"
   USE_NEUTRON=false
fi
echo "export OS_USERNAME=ci-user
export OS_TENANT_NAME=ci
export OS_PASSWORD=nova
export OPENSTACK_HOST=$OPENSTACK_HOST
export HOST=$HOST
export USE_NEUTRON=$USE_NEUTRON
export OS_AUTH_URL=http://$OPENSTACK_HOST:5000/v2.0/
" | sudo tee /home/jenkins/ci_openrc

sudo su - jenkins -c "echo '
JENKINS_PUBLIC_KEY' >> /home/jenkins/.ssh/authorized_keys"
sync
sleep 20
