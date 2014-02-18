#!/bin/bash

#jenkins-cli -s http://127.0.0.1:8080/jenkins quiet-down
#sleep 5
for i in $(nodepool-client list | grep ci-lab | awk -F '|' '{ print $2 }'); do nodepool-client delete $i; done
#jenkins-cli -s http://127.0.0.1:8080/jenkins cancel-quiet-down
