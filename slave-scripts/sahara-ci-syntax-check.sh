#!/bin/bash -x

FAILED_TESTS=""

check_return_code() {
  code=$1
  test_name=$2
  if [ $code -ne 0 ]; then
    FAILED_TESTS+="${test_name} syntax wrong; "
  fi
}

echo "Check bash syntax..."
for file in `find . -name "*.sh"`; do
  bash -n $file
  check_return_code $? "Bash: $file"
done

echo "Check python syntax..."
for file in `find . -name "*.py"`; do
  python -m py_compile $file
  check_return_code $? "Python: $file"
done

echo "Check zuul config syntax..."
zuul-server -c config/zuul/zuul.conf -l config/zuul/layout.yaml -t
check_return_code $? "Zuul conf"

echo "Check nodepool yaml syntax..."
ruby -e "require 'yaml'; y=YAML.load_file('config/nodepool/sahara.yaml')"
check_return_code $? "Nodepool conf"

echo "Check Jenkins Job Builder syntax..."
jenkins-jobs test -r -o $WORKSPACE ./jenkins_job_builder
check_return_code $? "Jenkins Job Builder"

if [ -n "$FAILED_TESTS" ]; then
   echo "$FAILED_TESTS"
   exit 1
else
   echo "Syntax checks passed"
   exit 0
fi
