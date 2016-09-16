#!/usr/bin/env python

import os
import re
import sys

import yaml

layout = yaml.load(open(sys.argv[1]))

JENKINS_JOBS = [
    'update-pool',
    'daily-log-publisher-43',
    'integration-cleanup',
    'jobs-updater',
    'daily-log-publisher-42',
    'update-config'
]


def grep(source, pattern):
    found = False
    p = re.compile(pattern)
    for line in source:
        if p.match(line):
            found = True
            break
    return found


def get_pipelines():
    pipelines = []
    for pipeline in layout['pipelines']:
        pipelines.append(pipeline['name'])
    return pipelines


def check_jobs():
    errors = False

    pipelines = get_pipelines()

    job_list_file = sys.argv[2]
    if not os.path.isfile(job_list_file):
        print("Job list file %s does not exist, not checking jobs section"
              % job_list_file)
        return False

    with open(job_list_file, 'r') as f:
        job_list = [line.rstrip() for line in f]

    zuul_jobs = []

    for project in layout['projects']:
        for pipeline in pipelines:
            jobs = project.get(pipeline, [])
            for job in jobs:
                zuul_jobs.append(job)
                found = grep(job_list, job)
                if not found:
                    print ("Regex %s has no matches in job list" % job)
                    errors = True

    for job in JENKINS_JOBS:
        job_list.remove(job)

    for job in job_list[1:]:
        if job not in zuul_jobs:
            print ("Job %s has no matches in zuul layout" % job)
            errors = True

    return errors

if __name__ == "__main__":
    sys.exit(check_jobs())
