#!/bin/bash

cd /opt/ci/jenkins-jobs/sahara-ci-config/slave-scripts
sleep 20

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
     JOB_TYPE=hdp-v1                                                        
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
    python cleanup.py cleanup-heat ci-$PREV_BUILD-$JOB_TYPE
else                                                                            
    python cleanup.py cleanup -$PREV_BUILD-$JOB_TYPE
fi
