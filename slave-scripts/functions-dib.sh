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
     delete_image ${plugin}_${os}_latest
     rename_image "$CUR_IMAGE" ${plugin}_${os}_latest
  fi
}

delete_image() {
   # "|| true" here, to avoid error code producing in case of missing image
   glance image-delete $1 || true
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
   glance image-create --name $1 --file $1.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' $image_properties
}

rename_image() {
   # 1 - source image, 2 - target image
   glance image-update $1 --name $2
}

upload_image() {
   local plugin=$1
   local username=$2
   local image=$3
   delete_image "$image"
   case "$plugin" in
           vanilla_1.2.1)
             image_properties="--property _sahara_tag_1.2.1=True --property _sahara_tag_1.1.2=True --property _sahara_tag_vanilla=True --property _sahara_username=${username}"
           ;;
           vanilla_2.6.0)
             image_properties="--property _sahara_tag_2.6.0=True --property _sahara_tag_vanilla=True --property _sahara_username=${username}"
           ;;
           hdp_1.3.2)
             image_properties="--property _sahara_tag_1.3.2=True --property _sahara_tag_hdp=True --property _sahara_username=${username}"
           ;;
           hdp_2.0.6)
             image_properties="--property _sahara_tag_2.0.6=True --property _sahara_tag_hdp=True --property _sahara_username=${username}"
           ;;
           cdh_5.3.0)
             image_properties="--property _sahara_tag_5.3.0=True --property _sahara_tag_5=True --property _sahara_tag_cdh=True --property _sahara_username=${username}"
           ;;
           cdh_5.4.0)
             image_properties="--property _sahara_tag_5.4.0=True --property _sahara_tag_cdh=True --property _sahara_username=${username}"
           ;;
           spark_1.0.0)
             image_properties="--property _sahara_tag_spark=True --property _sahara_tag_1.0.0=True --property _sahara_username=${username}"
           ;;
           mapr_4.0.2.mrv2)
             image_properties="--property _sahara_tag_mapr=True --property _sahara_tag_4.0.2.mrv2=True --property _sahara_username=${username}"
           ;;
   esac
   register_new_image "$image" "$image_properties"
   CUR_IMAGE="$image"
}
