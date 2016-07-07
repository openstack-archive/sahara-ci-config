#!/bin/bash -xe

CUR_IMAGE=none

check_error_code() {
   if [ "$1" != "0" -o ! -f "$2" ]; then
       echo "$2 image isn't build"
       exit 1
   fi
}

cleanup_image() {
  local plugin=$1
  local os=$2
  if [ "$ZUUL_PIPELINE" == "check" -o "$ZUUL_BRANCH" != "master" ]; then
     delete_image "$CUR_IMAGE"
  else
     delete_image ${plugin}_${os}
     rename_image "$CUR_IMAGE" ${plugin}_${os}
  fi
}

delete_image() {
   id=$(openstack image list | grep -w $1 | awk '{print $2}')
   if [ -n "$id" ]; then
     openstack image delete $id
   fi
}

failure() {
  local reason=$1
  echo "$reason"
  print_python_env
  delete_image "$CUR_IMAGE"
  exit 1
}

register_new_image() {
   local image_name=$1
   local image_properties=$2
   openstack image create $image_name --file $image_name.qcow2 --disk-format qcow2 --container-format bare --property '_sahara_tag_ci'='True' $image_properties
}

rename_image() {
   # 1 - source image, 2 - target image
   id=$(openstack image list | grep -w $1 | awk '{print $2}')
   openstack image set "$id" --name $2
}

upload_image() {
   local plugin=$1
   local username=$2
   local image=$3
   delete_image "$image"
   case "$plugin" in
           vanilla_2.6.0)
             image_properties="--property _sahara_tag_2.6.0=True --property _sahara_tag_vanilla=True --property _sahara_username=${username}"
           ;;
           vanilla_2.7.1)
             image_properties="--property _sahara_tag_2.7.1=True --property _sahara_tag_vanilla=True --property _sahara_username=${username}"
           ;;
           ambari_2.1)
             image_properties="--property _sahara_tag_2.2=True --property _sahara_tag_2.3=True --property _sahara_tag_ambari=True --property _sahara_username=${username}"
           ;;
           cdh_5.3.0)
             image_properties="--property _sahara_tag_5.3.0=True --property _sahara_tag_5=True --property _sahara_tag_cdh=True --property _sahara_username=${username}"
           ;;
           cdh_5.4.0)
             image_properties="--property _sahara_tag_5.4.0=True --property _sahara_tag_cdh=True --property _sahara_username=${username}"
           ;;
           cdh_5.5.0)
             image_properties="--property _sahara_tag_5.5.0=True --property _sahara_tag_cdh=True --property _sahara_username=${username}"
           ;;
           cdh_5.7.0)
             image_properties="--property _sahara_tag_5.7.0=True --property _sahara_tag_cdh=True --property _sahara_username=${username}"
           ;;
           spark_1.0.0)
             image_properties="--property _sahara_tag_spark=True --property _sahara_tag_1.0.0=True --property _sahara_username=${username}"
           ;;
           spark_1.3.1)
             image_properties="--property _sahara_tag_spark=True --property _sahara_tag_1.3.1=True --property _sahara_username=${username}"
           ;;
	       spark_1.6.0)
             image_properties="--property _sahara_tag_spark=True --property _sahara_tag_1.6.0=True --property _sahara_username=${username}"
           ;;
           mapr_5.0.0.mrv2)
             image_properties="--property _sahara_tag_mapr=True --property _sahara_tag_5.0.0.mrv2=True --property _sahara_username=${username}"
           ;;
           mapr_5.1.0.mrv2)
             image_properties="--property _sahara_tag_mapr=True --property _sahara_tag_5.1.0.mrv2=True --property _sahara_username=${username}"
           ;;
           storm_1.0.1)
             image_properties="--property _sahara_tag_storm=True --property _sahara_tag_1.0.1=True --property _sahara_username=${username}"
   esac
   register_new_image "$image" "$image_properties"
   CUR_IMAGE="$image"
}
