#!/bin/bash

JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $4 }')                          
                                                                                                                                                                
if [ $JOB_TYPE == 'heat' ]                                                      
then                                                                                                                                   
    JOB_TYPE=$(echo $PREV_JOB | awk -F '-' '{ print $5 }')                      
    python /var/lib/jenkins/ci-python-scripts/prepare_vm.py cleanup-heat ci-$PREV_BUILD-$JOB_TYPE
else                                                                            
    python /var/lib/jenkins/ci-python-scripts/prepare_vm.py cleanup $PREV_BUILD                            
fi
