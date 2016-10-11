#!/bin/bash -xe
#
#    Copyright (C) 2013,2014 Loic Dachary <loic@dachary.org>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
if [ -z "$1" ]; then
   echo "You must specify full path for Ceph installing"
   exit 1
fi
old=false
if [ -d "$1" ]; then
   read -p "Directory '$1' already exists, do you really want to recreate it? (Y/N) Or replace old? (R)" ynr
   case $ynr in
        [Yy]* ) echo "Recreating directory" ;;
        [Nn]* ) echo "Specify another directory" ; exit 0;;
        [Rr]* ) echo "Using old directory"; old=true;;
        * ) echo "Please answer yes, no or replace";;
   esac
fi

set -e
set -u

DIR=$1

if ! dpkg -l ceph ; then
 wget -q -O- 'https://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' | sudo apt-key add -
 echo deb http://ceph.com/debian-dumpling/ "$(lsb_release -sc)" main | sudo tee /etc/apt/sources.list.d/ceph.list
fi
sudo apt-get update
sudo apt-get --yes install ceph ceph-common

# get rid of process and directories leftovers
pkill ceph-mon || true
pkill ceph-osd || true
if $old; then
   rm -rf "${DIR:?}/"*
else
   rm -rf "${DIR}"
fi

# cluster wide parameters
mkdir -p ${DIR}/log
cat >> $DIR/ceph.conf <<EOF
[global]
fsid = $(uuidgen)
osd crush chooseleaf type = 0
run dir = ${DIR}/run
auth cluster required = none
auth service required = none
auth client required = none
osd pool default size = 1
EOF
export CEPH_ARGS="--conf ${DIR}/ceph.conf"

# single monitor
MON_DATA=${DIR}/mon
mkdir -p $MON_DATA

cat >> $DIR/ceph.conf <<EOF
[mon.0]
log file = ${DIR}/log/mon.log
chdir = ""
mon cluster log file = ${DIR}/log/mon-cluster.log
mon data = ${MON_DATA}
mon addr = 127.0.0.1
EOF

ceph-mon --id 0 --mkfs --keyring /dev/null
touch ${MON_DATA}/keyring
ceph-mon --id 0

# single osd
OSD_DATA=${DIR}/osd
mkdir ${OSD_DATA}

cat >> $DIR/ceph.conf <<EOF
[osd.0]
log file = ${DIR}/log/osd.log
chdir = ""
osd data = ${OSD_DATA}
osd journal = ${OSD_DATA}.journal
osd journal size = 100
EOF

OSD_ID=$(ceph osd create)
ceph osd crush add osd.${OSD_ID} 1 root=default host=localhost
ceph-osd --id ${OSD_ID} --mkjournal --mkfs
ceph-osd --id ${OSD_ID}

# check that it works
rados --pool data put group /etc/group
rados --pool data get group ${DIR}/group
diff /etc/group ${DIR}/group
ceph osd tree

# display usage instructions
echo export CEPH_ARGS="'--conf ${DIR}/ceph.conf'"
echo ceph osd tree

sleep 5
sudo cp $DIR/ceph.conf /etc/ceph/

CEPH_HEALTH=$(ceph health)
if [ "$CEPH_HEALTH" == "HEALTH_OK" ]; then
   echo "Ceph is installed successfully and working OK."
   echo
   echo "-------------------------------------------"
   echo "Do not forget to add following parameters to cinder.conf:"
   echo "volume_driver=cinder.volume.drivers.rbd.RBDDriver"
   echo "rbd_pool=data"
   echo "Then restart Cinder services."
else
   echo "Ceph is installed, but failed to start."
fi
