#!/bin/bash

CUR_IMAGE=none

register_new_image() {
   local image_name=$1
   local image_properties=$2
   glance image-create --name $1 --file $1.qcow2 --disk-format qcow2 --container-format bare --is-public=true --property '_sahara_tag_ci'='True' "$image_properties"
}

delete_image() {
   glance image-delete $1
}

upload_image() {
   local plugin=$1
   local username=$2
   local image=$3
   delete_image "$image"

   case "$plugin" in
           vanilla-1)
             image_properties="--property '_sahara_tag_1.2.1'='True' --property '_sahara_tag_1.1.2'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'=${username}"
           ;;
           vanilla-2.4)
             image_properties="--property '_sahara_tag_2.4.1'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'=${username}"
           ;;
           vanilla-2.6)
             image_properties="--property '_sahara_tag_2.6.0'='True' --property '_sahara_tag_vanilla'='True' --property '_sahara_username'=${username}"
           ;;
           hdp1)
             image_properties="--property '_sahara_tag_1.3.2'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'=${username}"
           ;;
           hdp2)
             image_properties="--property '_sahara_tag_2.0.6'='True' --property '_sahara_tag_hdp'='True' --property '_sahara_username'=${username}"
           ;;
           cdh)
             image_properties="--property '_sahara_tag_5.3.0'='True' --property '_sahara_tag_5'='True' --property '_sahara_tag_cdh'='True' --property '_sahara_username'=${username}"
           ;;
           spark)
             image_properties="--property '_sahara_tag_spark'='True' --property '_sahara_tag_1.0.0'='True'  --property '_sahara_username'=${username}"
           ;;
   esac
   register_new_image "$image" "$image_properties"
   CUR_IMAGE="$image"
}

rename_image() {
   # 1 - source image, 2 - target image
   glance image-update $1 --name $2
}

check_error_code() {
   if [ "$1" != "0" -o ! -f "$2" ]; then
       echo "$2 image doesn't build"
       exit 1
   fi
}

failure() {
  local reason=$1
  echo "$reason"
  print_python_env
  delete_image "$CUR_IMAGE"
  exit 1
}

cleanup_image() {
  local job_type=$1
  local os=$2
  if [ "$ZUUL_PIPELINE" == "check" -o "$ZUUL_BRANCH" != "master" ]; then
     delete_image "$CUR_NAME"
  else
     case $job_type in
        vanilla*)
           hadoop_version=$(echo $job_type | awk -F '_' '{print $2}')
           delete_image ${os}_vanilla_${hadoop_version}_latest
           rename_image "$CUR_NAME" ${os}_vanilla_${hadoop_version}_latest
           ;;
        hdp_1)
           delete_image sahara_hdp_1_latest
           rename_image "$CUR_NAME" sahara_hdp_1_latest
           ;;
        hdp_2)
           delete_image sahara_hdp_2_latest
           rename_image "$CUR_NAME" sahara_hdp_2_latest
           ;;
        cdh)
           delete_image ${os}_cdh_latest
           rename_image "$CUR_NAME" ${os}_cdh_latest
           ;;
        spark)
           delete_image sahara_spark_latest
           rename_image "$CUR_NAME" sahara_spark_latest
           ;;
     esac
  fi
}

run_tests_for_dib_image() {
  local config=$1
  local plugin=$2
  echo "Integration tests are started"
  export PYTHONUNBUFFERED=1
  if [[ "$JOB_NAME" =~ scenario ]]; then
      tox -e scenario $config || failure "Integration tests are failed"
  else
      tox -e integration -- $plugin --concurrency=1 || failure "Integration tests are failed"
  fi
}
