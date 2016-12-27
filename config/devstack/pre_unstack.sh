#!/bin/bash -xe
TOP_DIR=$(cd $(dirname "$0") && pwd)
ADMIN_RCFILE=$TOP_DIR/openrc

source $TOP_DIR/functions-common

if [ -e "$ADMIN_RCFILE" ]; then
    source $ADMIN_RCFILE admin admin
else
    echo "Can't source '$ADMIN_RCFILE'!"
    exit 1
fi

get_id() {
    result=$(openstack image list | grep $(basename -s .qcow2 $1) | awk '{print $2}')
    echo $result
}

VANILLA_2_7_1_IMAGE_PATH=/home/ubuntu/images/vanilla_2.7.1_u14.qcow2
CENTOS7_AMBARI_2_2_IMAGE_PATH=/home/ubuntu/images/ambari_2.2_c7.qcow2
UBUNTU_AMBARI_2_2_IMAGE_PATH=/home/ubuntu/images/ambari_2.2_u14.qcow2
UBUNTU_CDH_5_5_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.5.0_u14.qcow2
CENTOS_CDH_5_5_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.5.0_c6.6.qcow2
CENTOS7_CDH_5_5_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.5.0_c7.qcow2
CENTOS7_CDH_5_7_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.7.0_c7.qcow2
UBUNTU_CDH_5_7_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.7.0_u14.qcow2
CENTOS7_CDH_5_9_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.9.0_c7.qcow2
UBUNTU_CDH_5_9_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.9.0_u14.qcow2
SPARK_1_6_0_IMAGE_PATH=/home/ubuntu/images/spark_1.6.0_u14.qcow2
MAPR_5_1_0_MRV2_IMAGE_PATH=/home/ubuntu/images/mapr_5.1.0.mrv2_u14.qcow2
MAPR_5_2_0_MRV2_IMAGE_PATH=/home/ubuntu/images/mapr_5.2.0.mrv2_u14.qcow2
STORM_1_0_1_IMAGE_PATH=/home/ubuntu/images/storm_1.0.1_u14.qcow2


openstack image save --file $VANILLA_2_7_1_IMAGE_PATH $(get_id $VANILLA_2_7_1_IMAGE_PATH)
openstack image save --file $CENTOS7_AMBARI_2_2_IMAGE_PATH $(get_id $CENTOS7_AMBARI_2_2_IMAGE_PATH)
openstack image save --file $UBUNTU_AMBARI_2_2_IMAGE_PATH $(get_id $UBUNTU_AMBARI_2_2_IMAGE_PATH)
openstack image save --file $UBUNTU_CDH_5_5_0_IMAGE_PATH $(get_id $UBUNTU_CDH_5_5_0_IMAGE_PATH)
openstack image save --file $CENTOS_CDH_5_5_0_IMAGE_PATH $(get_id $CENTOS_CDH_5_5_0_IMAGE_PATH)
openstack image save --file $CENTOS7_CDH_5_5_0_IMAGE_PATH $(get_id $CENTOS7_CDH_5_5_0_IMAGE_PATH)
openstack image save --file $CENTOS7_CDH_5_7_0_IMAGE_PATH $(get_id $CENTOS7_CDH_5_7_0_IMAGE_PATH)
openstack image save --file $UBUNTU_CDH_5_7_0_IMAGE_PATH $(get_id $UBUNTU_CDH_5_7_0_IMAGE_PATH)
openstack image save --file $CENTOS7_CDH_5_9_0_IMAGE_PATH $(get_id $CENTOS7_CDH_5_9_0_IMAGE_PATH)
openstack image save --file $UBUNTU_CDH_5_9_0_IMAGE_PATH $(get_id $UBUNTU_CDH_5_9_0_IMAGE_PATH)
openstack image save --file $SPARK_1_6_0_IMAGE_PATH $(get_id $SPARK_1_6_0_IMAGE_PATH)
openstack image save --file $MAPR_5_1_0_MRV2_IMAGE_PATH $(get_id $MAPR_5_1_0_MRV2_IMAGE_PATH)
openstack image save --file $MAPR_5_2_0_MRV2_IMAGE_PATH $(get_id $MAPR_5_2_0_MRV2_IMAGE_PATH)
openstack image save --file $STORM_1_0_1_IMAGE_PATH $(get_id $STORM_1_0_1_IMAGE_PATH)

bash $TOP_DIR/unstack.sh

