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

create_new_image() {
   local image_name=$1
   local image_properties=$2
   openstack image create $image_name --file $image_name.qcow2 --disk-format qcow2 --container-format bare --property '_sahara_tag_ci'='True'
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
   local plugin_name
   plugin_name=$(echo ${plugin//_/ } | awk '{ print $1 }')
   plugin_version=$(echo ${plugin//_/ } | awk '{ print $2 }')
   delete_image "$image"
   case "$plugin" in
           ambari_2.1)
             additional_tags="2.2 2.3"
           ;;
           ambari_2.2)
             additional_tags="2.4 2.3"
           ;;
   esac
   create_new_image "$image"
   openstack dataprocessing image register $image --username $username
   openstack dataprocessing image tags add $image --tags $plugin_name $plugin_version $additional_tags
   CUR_IMAGE="$image"
}
