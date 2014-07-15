#!/bin/bash

cd /opt/ci/jenkins-jobs/sahara-ci-config/slave-scripts
sleep 20

source $WORKSPACE/credentials
JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $1 }')
HOST=$(echo $HOST_NAME | awk -F '-' '{ print $2 }' | cut -c1-2)
if [ "$HOST" == "ci" ]; then
    export os_auth_url="http://$OPENSTACK_HOST_CI_LAB:5000/v2.0"
    export os_image_endpoint="http://$OPENSTACK_HOST_CI_LAB:8004/v1/$CI_LAB_TENANT_ID"
else
    export os_auth_url="http://$OPENSTACK_HOST_SAHARA_STACK:5000/v2.0"
    export os_image_endpoint="http://$OPENSTACK_HOST_SAHARA_STACK:8004/v1/$STACK_SAHARA_TENANT_ID"
fi
if [ $JOB_TYPE == 'diskimage' ]; then
    PLUGIN=$(echo $PREV_JOB | awk -F '-' '{ print $3 }')
    if [ $PLUGIN == 'vanilla' ]; then
        IMAGE_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')
        if [ "$IMAGE_TYPE" == "centos" ]; then
            os="cos"
        elif [ "$IMAGE_TYPE" == "fedora" ]; then
            os="fos"
        elif [ "$IMAGE_TYPE" == "ubuntu" ]; then
            os="uos"
        fi
        python cleanup.py cleanup $HOST-$os-$PREV_BUILD-vanilla-v1
        python cleanup.py cleanup $HOST-$os-$PREV_BUILD-vanilla-v2
    elif [ $PLUGIN == 'hdp1' ]; then
        python cleanup.py cleanup $HOST-cos-$PREV_BUILD-hdp
    elif [ $PLUGIN == 'hdp2' ]; then
        python cleanup.py cleanup $HOST-cos-$PREV_BUILD-hdp-v2
    else
        python cleanup.py cleanup $HOST-uos-$PREV_BUILD-$PLUGIN
    fi
else
    JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')
    if [ $JOB_TYPE == 'vanilla1' ]
    then
        JOB_TYPE=vanilla-v1
    elif [ $JOB_TYPE == 'vanilla2' ]
    then
        JOB_TYPE=vanilla-v2
    fi
    if [ $JOB_TYPE == 'hdp1' ]
    then
        JOB_TYPE=hdp
    elif [ $JOB_TYPE == 'hdp2' ]
    then
        JOB_TYPE=hdp-v2
    fi
    if [ $JOB_TYPE == 'heat' ]
    then
       JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $5 }')
        if [ $JOB_TYPE == 'vanilla1' ]
        then
            JOB_TYPE=vanilla-v1
        fi
        python cleanup.py cleanup-heat $HOST-$PREV_BUILD-$JOB_TYPE
    else
        
        python cleanup.py cleanup -$PREV_BUILD-$JOB_TYPE
    fi
fi
