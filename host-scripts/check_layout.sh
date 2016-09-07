#!/bin/bash

mkdir out
jenkins-jobs test -o out/ $WORKSPACE/jenkins_job_builder/


find out/ -printf "%f\n" > job-list.txt

python $WORKSPACE/host-scripts/check_layout.py $WORKSPACE/config/zuul/layout.yaml job-list.txt
