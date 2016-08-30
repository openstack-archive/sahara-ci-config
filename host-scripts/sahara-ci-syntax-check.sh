#!/bin/bash

cd $WORKSPACE

FAILED_TESTS=""

check_return_code() {
  code=$1
  test_name=$2
  if [ $code -ne 0 ]; then
    FAILED_TESTS+="${test_name} syntax is wrong; "
  fi
}

echo "Checking bash syntax..."
bash_status=0
for file in `find . -name "*.sh"`; do
  bash -n $file
  bash_status=$(( $bash_status + $? ))
done
check_return_code $bash_status "Bash"

python_status=0
echo "Checking python syntax..."
for file in `find . -name "*.py"`; do
  python -m py_compile $file
  python_status=$(( $python_status + $? ))
done
check_return_code $python_status "Python"

echo "Checking zuul config syntax..."
zuul-server -c config/zuul/zuul.conf -l config/zuul/layout.yaml -t
check_return_code $? "Zuul conf"

echo "Checking nodepool yaml syntax..."
ruby -e "require 'yaml'; y=YAML.load_file('config/nodepool/sahara.yaml')"
check_return_code $? "Nodepool conf"

echo "Checking Jenkins Job Builder jobs syntax..."
#jenkins-jobs -l debug test -r -o $WORKSPACE ./jenkins_job_builder
jenkins-jobs -l debug test -o $WORKSPACE ./jenkins_job_builder
check_return_code $? "Jenkins Job Builder"

echo "Checking bash syntax (shellcheck)..."
for file in `find . -name "*.sh"`; do
  shellcheck $file -e SC2086,SC2016,SC2034,SC2046,SC2140
#  shellcheck $file -e SC2086,SC2034
  shellcheck_status=$(( $shellcheck_status + $? ))
done
echo
check_return_code $shellcheck_status "shellcheck"

if [ -n "$FAILED_TESTS" ]; then
   echo "$FAILED_TESTS"
   exit 1
else
   echo "Syntax checks passed"
   exit 0
fi
