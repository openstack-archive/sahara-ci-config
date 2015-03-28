#!/bin/bash -e

cd sahara-ci-config/slave-scripts
sleep 20

source $JENKINS_HOME/credentials
set -x
job_type=$(echo $PREV_JOB | awk -F '-' '{ print $1 }')
if [[ "$HOST_NAME" =~ neutron ]]; then
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
    if [ "$job_type" == "dib" ]; then
      engine=$(echo $PREV_JOB | awk -F '-' '{ print $3 }')
    else
      engine=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')
    fi

    if [ "$engine" == "heat" ]
    then
        python cleanup.py cleanup-heat .*$host-$CHANGE_NUMBER-$CLUSTER_HASH.*
    else
        python cleanup.py cleanup .*$host-$CHANGE_NUMBER-$CLUSTER_HASH.*
    fi
fi
