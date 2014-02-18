#!/bin/bash -xe

source /usr/local/jenkins/slave_scripts/select-mirror.sh openstack savanna

set -o pipefail

# replace hacking with master tarball
sed -i '/^hacking/d' test-requirements.txt
echo -e "-f http://tarballs.openstack.org/hacking/hacking-master.tar.gz#egg=hacking-master\nhacking==master\n$(cat test-requirements.txt)" > test-requirements.txt

tox -v -epep8 -- --statistics | tee pep8.txt
set +o pipefail
