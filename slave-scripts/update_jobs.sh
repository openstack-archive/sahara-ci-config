#!/bin/bash
cd /opt/ci/jenkins-jobs
rm -rf savanna-ci-config
git clone https://github.com/stackforge/savanna-ci-config.git
cd savanna-ci-config
jenkins-jobs update jenkins_job_builder
