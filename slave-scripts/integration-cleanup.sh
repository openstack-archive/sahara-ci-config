#!/bin/bash

cd /opt/ci/jenkins-jobs/sahara-ci-config/slave-scripts
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
if [ $JOB_TYPE == 'dib' ]; then
    PLUGIN=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')
    if [[ $PLUGIN =~ 'vanilla' ]]; then
        IMAGE_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $5 }')
        if [ "$IMAGE_TYPE" == "centos" ]; then
            os="cos"
        elif [ "$IMAGE_TYPE" == "fedora" ]; then
            os="fos"
        elif [ "$IMAGE_TYPE" == "ubuntu" ]; then
            os="uos"
        fi
        HADOOP_VERSION=$(echo $PLUGIN | awk -F '_' '{ print $2}')
        if [ "$HADOOP_VERSION" == '1' ]; then
            python cleanup.py cleanup $HOST-$os-$HADOOP_VERSION-$PREV_BUILD-vanilla-v1
        elif [ "$HADOOP_VERSION" == '2.3' ]; then
            python cleanup.py cleanup $HOST-$os-2-3-$PREV_BUILD-vanilla-v2
        else
            python cleanup.py cleanup-heat $HOST-$os-2-4-$PREV_BUILD-vanilla-v2
        fi
    elif [ $PLUGIN == 'hdp_1' ]; then
        python cleanup.py cleanup $HOST-cos-1-$PREV_BUILD-hdp
    elif [ $PLUGIN == 'hdp_2' ]; then
        python cleanup.py cleanup-heat $HOST-cos-2-$PREV_BUILD-hdp-v2
    elif [[ $PLUGIN =~ 'cdh' ]]; then
        IMAGE_TYPE=$(echo $PREV_JOB | awk -F '_' '{ print $2 }')
        if [ "$IMAGE_TYPE" == "centos" ]; then
            os="cos"
        elif [ "$IMAGE_TYPE" == "ubuntu" ]; then
            os="uos"
        fi
        python cleanup.py cleanup $HOST-$os-2-$PREV_BUILD-cdh
    else
        python cleanup.py cleanup $HOST-uos-1-$PREV_BUILD-$PLUGIN
    fi
elif [[ $(echo $PREV_JOB | awk -F '-' '{ print $2 }') =~ ui ]]; then
    python cleanup.py cleanup $PREV_BUILD-selenium
else
    ENGINE=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')
    JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $5 }')
    HADOOP_VERSION=1
    if [[ $JOB_TYPE =~ 'vanilla' ]]
    then
        HADOOP_VERSION=$(echo JOB_TYPE | awk -F '_' '{ print $2 }')
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
    if [ $JOB_TYPE == 'hdp_1' ]
    then
        JOB_TYPE=hdp
    elif [ $JOB_TYPE == 'hdp_2' ]
    then
        HADOOP_VERSION=2
        JOB_TYPE=hdp-v2
    fi
    if [[ $JOB_TYPE =~ 'cdh' ]]
    then
        os_version=$(echo $JOB_TYPE | awk -F '_' '{ print $2}')
        if [ "$os_version" == "centos" ]; then
           HADOOP_VERSION=2c
        else
           HADOOP_VERSION=2u
        fi
        JOB_TYPE=cdh
    fi
    if [ $JOB_TYPE == 'transient' ]
        then
            JOB_TYPE=transient-vanilla
        fi
    if [ $ENGINE == 'heat' ]
    then
        python cleanup.py cleanup-heat $HOST-$HADOOP_VERSION-$PREV_BUILD-$JOB_TYPE
    else
        python cleanup.py cleanup $HOST-$HADOOP_VERSION-$PREV_BUILD-$JOB_TYPE
    fi
fi
set +x
