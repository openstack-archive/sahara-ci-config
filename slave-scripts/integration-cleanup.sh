#!/bin/bash

cd /opt/ci/jenkins-jobs/sahara-ci-config/slave-scripts
sleep 20

source $JENKINS_HOME/credentials
JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $1 }')
HOST="c"$(echo $HOST_NAME | awk -F '-' '{ print $3 }')
if [ "$HOST" == "c1" ]; then
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
        HADOOP_VERSION=$(echo $PREV_JOB | awk -F '-' '{ print $5}')
        if [ "$HADOOP_VERSION" == '1' ]; then
            python cleanup.py cleanup $HOST-$os-$HADOOP_VERSION-$PREV_BUILD-vanilla-v1
        elif [ "$HADOOP_VERSION" == '2.3' ]; then
            python cleanup.py cleanup $HOST-$os-2-3-$PREV_BUILD-vanilla-v2
        else
            python cleanup.py cleanup $HOST-$os-2-4-$PREV_BUILD-vanilla-v2
        fi
    elif [ $PLUGIN == 'hdp1' ]; then
        python cleanup.py cleanup $HOST-cos-1-$PREV_BUILD-hdp
    elif [ $PLUGIN == 'hdp2' ]; then
        python cleanup.py cleanup $HOST-cos-2-$PREV_BUILD-hdp-v2
    else
        python cleanup.py cleanup $HOST-uos-1-$PREV_BUILD-$PLUGIN
    fi
else
    JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')
    HADOOP_VERSION=1
    if [ $JOB_TYPE == 'vanilla' ]
    then
        HADOOP_VERSION=$(echo $PREV_JOB | awk -F '-' '{ print $5}')
        if [ "$HADOOP_VERSION" == '1' ]; then
            JOB_TYPE=vanilla-v1
        else
            JOB_TYPE=vanilla-v2
            if [ "$HADOOP_VERSION" == '2.3' ]; then
                HADOOP_VERSION=2-3
            else
                HADOOP_VERSION=2-4
            fi
        fi
    fi
    if [ $JOB_TYPE == 'hdp1' ]
    then
        JOB_TYPE=hdp
    elif [ $JOB_TYPE == 'hdp2' ]
    then
        JOB_TYPE=hdp-v2
        HADOOP_VERSION=2
    fi
    if [ $JOB_TYPE == 'heat' ]
    then
       JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $5 }')
        if [ $JOB_TYPE == 'vanilla1' ]
        then
            JOB_TYPE=vanilla-v1
        fi
        python cleanup.py cleanup-heat $HOST-$HADOOP_VERSION-$PREV_BUILD-$JOB_TYPE
    else
        python cleanup.py cleanup $HOST-$HADOOP_VERSION-$PREV_BUILD-$JOB_TYPE
    fi
fi
