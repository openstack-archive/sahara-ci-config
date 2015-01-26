import os
import sys, getopt
import socket
import time
import ConfigParser
from novaclient.v1_1 import client as nc
import requests
from random import randint
from keystoneclient.v2_0 import client as kc
from heatclient import client as hc
from heatclient import exc as hc_exc
from cinderclient import client as cc
import re

CONF = dict()
CONF_FILE = '/etc/jenkins_jobs/credentials.conf'

def load_conf():
    # load credentials and configs
    config = ConfigParser.ConfigParser()
    config.readfp(open(CONF_FILE))
    for key, val in config.items("default"):
        CONF[key] = val

    for env_item in os.environ:
        CONF[env_item] = os.environ[env_item]

def get_nova_client():
    return nc.Client(username = CONF["os_username"],
        api_key = CONF["os_password"],
        auth_url = CONF["os_auth_url"],
        project_id = CONF["os_tenant_name"]
    )

def get_auth_token():
    keystone = kc.Client(username = CONF["os_username"],
        password = CONF["os_password"],
        tenant_name = CONF["os_tenant_name"],
        auth_url = CONF["os_auth_url"]
    )
    return keystone.auth_token

def get_heat_client():
    return hc.Client('1', endpoint=CONF["os_image_endpoint"], token=get_auth_token())

def get_cinder_client():
    return cc.Client('1', CONF["os_username"], CONF["os_password"], CONF["os_tenant_name"], CONF["os_auth_url"])

def cleanup_heat():
    current_name = sys.argv[2]
    client = get_heat_client()
    stacks = client.stacks.list()
    name_regex = re.compile(current_name)
    deleted_stacks = []

    for stack in stacks:
       if name_regex.match(stack.stack_name) :
         deleted_stacks.append(stack.stack_name)
         print stack.stack_name
         client.stacks.delete(stack.stack_name)
    # Let Heat delete stacks
    time.sleep(30)
    stacks = client.stacks.list()
    for stack in stacks:
       if stack.stack_name in deleted_stacks :
         #Resource cleanup is required
         print "At least one stack wasn't deleted!"
         print "Performing resources cleanup..."
         cleanup()
         return

def cleanup():
    client = get_nova_client()
    cinder_client = get_cinder_client()
    servers = client.servers.list()
    volumes = cinder_client.volumes.list()
    secgroups = client.security_groups.list()
    current_name = sys.argv[2]
    name_regex = re.compile(current_name)

    for server in servers:
        if name_regex.match(server.name) :
            print server.name
            fl_ips = client.floating_ips.findall(instance_id=server.id)
            for fl_ip in fl_ips:
                    client.floating_ips.delete(fl_ip.id)
            client.servers.delete(server.id)

    time.sleep(20)
    for volume in volumes:
        if name_regex.match(volume.display_name) :
           print volume.display_name
           volume.delete()

    for group in secgroups:
        if name_regex.match(group.name) :
           print group.name
           group.delete()

def main(argv):
    load_conf()

    if "cleanup" in argv:
        cleanup()

    if "cleanup-heat" in argv:
        cleanup_heat()


if __name__ == "__main__":
    main(sys.argv[1:])
