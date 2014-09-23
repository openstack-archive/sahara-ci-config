#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <cache ip> <cache-dir>"
    exit 1
fi

CACHE_IP=${1}
CACHE_DIR=${2}

echo "Install apt-cacher-ng"
sudo apt-get install -y apt-cacher-ng

echo "Configure apt-cacher-ng"
sudo mkdir -p ${CACHE_DIR}
sudo chown apt-cacher-ng:apt-cacher-ng ${CACHE_DIR}
sudo sed -i "s/CacheDir:.*/CacheDir: ${CACHE_DIR//\//\\\/}/g" /etc/apt-cacher-ng/acng.conf

sudo service apt-cacher-ng restart

echo "Create repo files for CDH plugin"
mkdir -p apt-cacher/repolist
pushd apt-cacher
pushd repolist

wget http://archive.cloudera.com/cdh5/ubuntu/precise/amd64/cdh/cloudera.list -O cdh.list
wget http://archive.cloudera.com/cm5/ubuntu/precise/amd64/cm/cloudera.list -O cm.list

sed -i "s/http:\/\//http:\/\/${CACHE_IP}\//g" cdh.list cm.list

sudo apt-get install apache2 -y
sudo echo -e "Alias /cdh-repo ${CACHE_DIR}
<Directory ${CACHE_DIR}>
Order allow,deny
Allow from all
  Options +Indexes
</Directory>" > /etc/apache2/site-available/repo.conf
sudo a2ensite repo
sudo service apache2 reload
