#!/bin/bash

for i in $(nodepool-client list | grep ci-lab | awk -F '|' '{ print $2 }')
do 
   nodepool-client delete $i
   sleep 2
done
