#!/bin/bash -e

cd sahara-ci-config/slave-scripts
sleep 20

source $JENKINS_HOME/credentials
set -x
job_type=$(echo $PREV_JOB | awk -F '-' '{ print $1 }')
export os_username=$os_username
export os_password=$os_password
export os_tenant_name=$os_tenant_name
if [[ "$HOST_NAME" =~ 42 ]]; then
    export os_auth_url="http://$OPENSTACK_HOST_NEUTRON_LAB:5000/v2.0"
    export os_image_endpoint="http://$OPENSTACK_HOST_NEUTRON_LAB:8004/v1/$NEUTRON_LAB_TENANT_ID"
    host="c1"
else
    export os_auth_url="http://$OPENSTACK_HOST_NOVA_NET_LAB:5000/v2.0"
    export os_image_endpoint="http://$OPENSTACK_HOST_NOVA_NET_LAB:8004/v1/$NOVA_NET_LAB_TENANT_ID"
    host="c2"
fi
if [[ $(echo $PREV_JOB | awk -F '-' '{ print $2 }') =~ ui ]]; then
    python cleanup.py cleanup .*$PREV_BUILD-selenium.*
elif [ "$job_type" == "tempest" ]; then
    python cleanup.py cleanup .*sahara-cluster.*
else
    python cleanup.py cleanup-heat .*$host-$CHANGE_NUMBER-$CLUSTER_HASH.*
fi
