#!/bin/bash -xe

source /usr/local/jenkins/slave_scripts/select-mirror.sh openstack sahara

set -o pipefail

# replace hacking with master tarball
sed -i '/^hacking/d' test-requirements.txt
REQS=$(cat test-requirements.txt)
echo -e "-f http://tarballs.openstack.org/hacking/hacking-master.tar.gz#egg=hacking-master\nhacking==master\n${REQS}" > test-requirements.txt

sed -i '/^ignore/d' tox.ini
sed -ie 's/\(^exclude.*\)/\1,*sahara-ci-config*/' tox.ini

tox -v -epep8 -- --statistics | tee pep8.txt
