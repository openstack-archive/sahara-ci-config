#!/bin/bash -x
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
    result=$(glance image-list | grep $(basename -s .qcow2 $1) | awk '{print $2}')
    echo $result
}

VANILLA_2_6_0_IMAGE_PATH=/home/ubuntu/images/vanilla_2.6.0_u14.qcow2
VANILLA_2_7_1_IMAGE_PATH=/home/ubuntu/images/vanilla_2.7.1_u14.qcow2
HDP_2_0_6_IMAGE_PATH=/home/ubuntu/images/hdp_2.0.6_c6.6.qcow2
AMBARI_2_3_IMAGE_PATH=/home/ubuntu/images/ambari_2.1_c6.6.qcow2
CENTOS_CDH_5_3_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.3.0_c6.6.qcow2
UBUNTU_CDH_5_3_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.3.0_u12.qcow2
UBUNTU_CDH_5_4_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.4.0_u12.qcow2
CENTOS_CDH_5_4_0_IMAGE_PATH=/home/ubuntu/images/cdh_5.4.0_c6.6.qcow2
SPARK_1_0_0_IMAGE_PATH=/home/ubuntu/images/spark_1.0.0_u14.qcow2
SPARK_1_3_1_IMAGE_PATH=/home/ubuntu/images/spark_1.3.1_u14.qcow2
MAPR_5_0_0_MRV2_IMAGE_PATH=/home/ubuntu/images/mapr_5.0.0.mrv2_u14.qcow2
MAPR_5_1_0_MRV2_IMAGE_PATH=/home/ubuntu/images/mapr_5.1.0.mrv2_u14.qcow2


glance image-download --file $VANILLA_2_6_0_IMAGE_PATH $(get_id $VANILLA_2_6_0_IMAGE_PATH)
glance image-download --file $VANILLA_2_7_1_IMAGE_PATH $(get_id $VANILLA_2_7_1_IMAGE_PATH)
glance image-download --file $HDP_2_0_6_IMAGE_PATH $(get_id $HDP_2_0_6_IMAGE_PATH)
glance image-download --file $AMBARI_2_3_IMAGE_PATH $(get_id $AMBARI_2_3_IMAGE_PATH)
glance image-download --file $CENTOS_CDH_5_3_0_IMAGE_PATH $(get_id $CENTOS_CDH_5_3_0_IMAGE_PATH)
glance image-download --file $UBUNTU_CDH_5_3_0_IMAGE_PATH $(get_id $UBUNTU_CDH_5_3_0_IMAGE_PATH)
glance image-download --file $UBUNTU_CDH_5_4_0_IMAGE_PATH $(get_id $UBUNTU_CDH_5_4_0_IMAGE_PATH)
glance image-download --file $CENTOS_CDH_5_4_0_IMAGE_PATH $(get_id $CENTOS_CDH_5_4_0_IMAGE_PATH)
glance image-download --file $SPARK_1_0_0_IMAGE_PATH $(get_id $SPARK_1_0_0_IMAGE_PATH)
glance image-download --file $SPARK_1_3_1_IMAGE_PATH $(get_id $SPARK_1_3_1_IMAGE_PATH)
glance image-download --file $MAPR_5_0_0_MRV2_IMAGE_PATH $(get_id $MAPR_5_0_0_MRV2_IMAGE_PATH)
glance image-download --file $MAPR_5_1_0_MRV2_IMAGE_PATH $(get_id $MAPR_5_1_0_MRV2_IMAGE_PATH)

bash $TOP_DIR/unstack.sh

