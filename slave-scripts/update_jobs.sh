#!/bin/bash
cd /opt/ci/jenkins-jobs
rm -rf sahara-ci-config
git clone https://github.com/stackforge/sahara-ci-config.git
cd sahara-ci-config
jenkins-jobs update jenkins_job_builder
