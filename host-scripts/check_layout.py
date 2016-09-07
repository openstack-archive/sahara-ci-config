#!/usr/bin/env python

import os
import re
import sys

import yaml

layout = yaml.load(open(sys.argv[1]))


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

    for project in layout['projects']:
        for pipeline in pipelines:
            jobs = project.get(pipeline, [])
            for job in jobs:
                found = grep(job_list, job)
                if not found:
                    print ("Regex %s has no matches in job list" % job)
                    errors = True

    return errors

if __name__ == "__main__":
    sys.exit(check_jobs())
