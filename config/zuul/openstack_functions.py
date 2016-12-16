# Copyright 2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import uuid
from time import gmtime, strftime


def set_log_url(item, job, params):
    if hasattr(item.change, 'refspec'):
        path = "%s/%s/%s/%s" % (
            params['ZUUL_CHANGE'][-2:], params['ZUUL_CHANGE'],
            params['ZUUL_PATCHSET'], params['ZUUL_PIPELINE'])
    elif hasattr(item.change, 'ref'):
        path = "%s/%s/%s" % (
            params['ZUUL_NEWREV'][:2], params['ZUUL_NEWREV'],
            params['ZUUL_PIPELINE'])
    else:
        path = params['ZUUL_PIPELINE']
    params['BASE_LOG_PATH'] = path
    params['LOG_PATH'] = path + '/%s/%s/%s' % (job.name,
                                               strftime("%Y-%m-%d", gmtime()),
                                               params['ZUUL_UUID'][:7])


def single_use_node(item, job, params):
    set_log_url(item, job, params)
    if job.name not in ["sahara-ci-syntax-check", "sahara-ci-layout"]:
        params['OFFLINE_NODE_WHEN_COMPLETE'] = '1'


def set_params(item, job, params):
    single_use_node(item, job, params)
    params['CLUSTER_HASH'] = str(uuid.uuid4()).split('-')[0]
    params['ZUUL_BRANCH'] = params.get('ZUUL_BRANCH', 'master')
    params['ZUUL_REF'] = params.get('ZUUL_REF', 'master')
    params['ZUUL_CHANGE'] = params.get('ZUUL_CHANGE', 'master')
