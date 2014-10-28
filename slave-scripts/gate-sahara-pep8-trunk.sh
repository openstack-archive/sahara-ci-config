#!/bin/bash -xe

. $FUNCTION_PATH
set -o pipefail
enable_pypi

# replace hacking with master tarball
sed -i '/^hacking/d' test-requirements.txt
echo -e "-f http://tarballs.openstack.org/hacking/hacking-master.tar.gz#egg=hacking-master\nhacking==master\n$(cat test-requirements.txt)" > test-requirements.txt

sed -i '/^ignore/d' tox.ini
sed -ie 's/\(^exclude.*\)/\1,*sahara-ci-config*/' tox.ini
sed -ie 's/flake8==2.2.4/flake8==2.2.5/g' requirements.txt

tox -v -epep8 -- --statistics | tee pep8.txt
