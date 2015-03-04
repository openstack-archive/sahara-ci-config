#!/bin/bash

cd sahara-ci-config/slave-scripts
sleep 20

source $JENKINS_HOME/credentials
set -x
JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $1 }')
HOST=$(echo $HOST_NAME | awk -F '-' '{ print $2 }')
if [ "$HOST" == "neutron" ]; then
    export os_auth_url="http://$OPENSTACK_HOST_CI_LAB:5000/v2.0"
    export os_image_endpoint="http://$OPENSTACK_HOST_CI_LAB:8004/v1/$CI_LAB_TENANT_ID"
    HOST="c1"
else
    export os_auth_url="http://$OPENSTACK_HOST_SAHARA_STACK:5000/v2.0"
    export os_image_endpoint="http://$OPENSTACK_HOST_SAHARA_STACK:8004/v1/$STACK_SAHARA_TENANT_ID"
    HOST="c2"
fi
if [[ $(echo $PREV_JOB | awk -F '-' '{ print $2 }') =~ ui ]]; then
    python cleanup.py cleanup .*$PREV_BUILD-selenium.*
elif [ $JOB_TYPE == "tempest" ]; then
    python cleanup.py cleanup .*sahara-cluster.*
else
    ENGINE=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')
    if [ $ENGINE == 'heat' ]
    then
        python cleanup.py cleanup-heat .*$HOST-$CLUSTER_HASH-$CHANGE_NUMBER.*
    else
        python cleanup.py cleanup .*$HOST-$CLUSTER_HASH-$CHANGE_NUMBER.*
    fi
fi
