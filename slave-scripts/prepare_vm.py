import os
import sys, getopt
import socket
import time
import paramiko
import ConfigParser
from novaclient.v1_1 import client as nc
from jenkinsapi.jenkins import Jenkins
import requests
from random import randint
from keystoneclient.v2_0 import client as kc
from heatclient import client as hc

CONF = dict()
CONF_FILE = '/var/lib/jenkins/ci-python-scripts/resources/credentials.conf'

def load_conf():
    # load credentials and configs
    config = ConfigParser.ConfigParser()
    config.readfp(open(CONF_FILE))
    for key, val in config.items("default"):
        CONF[key] = val

    for env_item in os.environ:
        CONF[env_item] = os.environ[env_item]

    if not "vm_name" in CONF:
        CONF["vm_name"] = "jenkins-test-"

    if not "max_workers" in CONF:
        CONF["max_workers"] = 3

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
def get_jenkins():
    return Jenkins(baseurl="http://" + CONF["jenkins_host_port"],
        username=CONF["jenkins_username"],
        password=CONF["jenkins_password"])

def check_workers():
    jen = get_jenkins()

    nodeRequest = requests.get(
        "http://" + CONF["jenkins_host_port"] + "/computer/api/json")
    nodes = nodeRequest.json()

    devstack_nodes_count = 0
    for node in nodes["computer"]:
        if CONF["node_vm_name_prefix"] in node["displayName"]:
            devstack_nodes_count += 1

    max_workers = int(CONF["max_workers"])
    if devstack_nodes_count >= max_workers:
        print "Pool is full"
    else:
       boot_vm()

def boot_vm():
    print "Creating VM"

    jen = get_jenkins()
    client = get_nova_client()


    CONF["vm_name"] = CONF["vm_name"]+str(randint(1, 1000))
    name = CONF["vm_name"] 
 
    print CONF["key_name"]
    print CONF["vm_name"]

#    if sys.argv[2] != "":
#       CONF["vm_name"] = sys.argv[2]
#       name = sys.argv[2]

#    vm = client.servers.create(name,
#                    flavor = CONF["flavor_id"],
#                    image = CONF["image_id"],
#                    key_name = CONF["key_name"])
#
    nics = [{"net-id": CONF["network_id"], "v4-fixed-ip": ""}]
    vm = client.servers.create(name,
                    flavor = CONF["flavor_id"],
                    image = CONF["image_id"],
                    key_name = CONF["key_name"],
		    nics=nics)

    print "Waiting ACTIVE state"

    id = vm.id
    vm = client.servers.get(id)
    while vm.status != "ACTIVE":
        print "Status is " + vm.status
        vm = client.servers.get(id)
        time.sleep(2)

    floating_ip = client.floating_ips.create(CONF["floating_pool"])
    client.servers.get(id).add_floating_ip(floating_ip)

    print "Getting addresses"
    addresses = []
    while len(addresses) == 0:
        vm = client.servers.get(id)
        for network, address in vm.addresses.items():
            addresses.extend(address)

    print "Waiting vm up"
    ip = addresses[0]
    for addr_json in addresses:
        print addr_json
        if CONF["network_prefix"] in addr_json['addr']:
            ip = addr_json['addr']
            wait_vm_up(addr_json['addr'])
            break

    print "IP is " + ip


    #register jenkins worker
    jen.create_node(name,
        num_executors=1,
        remote_fs="/tmp",
        exclusive=True,
        labels=CONF["node_label"])

    #save vm_name, will be used to delete it
    _execute_command_on_node(ip,
        'echo "vm_name=' + CONF["vm_name"] +'" > /tmp/vmname')

    #bypass proxy
    #_execute_command_on_node(ip,
    #    "sudo bash -c 'echo " + CONF["jenkins_ip"] + " jenkins.savanna.mirantis.com >> /etc/hosts'")


    _execute_command_on_node(ip,
        "sudo bash -c 'echo " + CONF["jenkins_ip"] + " savanna-ci.vm.mirantis.net >> /etc/hosts'")

    time.sleep(2)

    _execute_command_on_node(ip,
        "sudo bash -c 'echo " + CONF["jenkins_ip"] + " jenkins.savanna.mirantis.com >> /etc/hosts'")

    #put a key
    transport = paramiko.Transport((ip, 22))
    transport.connect(username=CONF["slave_username"],
        pkey=paramiko.RSAKey.from_private_key_file(
            filename=os.path.expanduser("~/.ssh/id_rsa")))
    sftp = paramiko.SFTPClient.from_transport(transport)
    remotepath=CONF["remote_key_path"]
    localpath=CONF["local_key_path"]
    sftp.put(localpath, remotepath)

    sftp.close()
    transport.close()

    #set -rw------- to key file
    _execute_command_on_node(ip, "chmod 600 " + CONF["remote_key_path"])

    #no confirmation ssh
    _execute_command_on_node(ip,
        'echo "Host *" > /home/ubuntu/.ssh/config')
    _execute_command_on_node(ip,
        'echo "    StrictHostKeyChecking no" >> /home/ubuntu/.ssh/config')

    #pip mirror
    _execute_command_on_node(ip,
        'mkdir /home/ubuntu/.pip')
    _execute_command_on_node(ip,
        'echo "[global]" >> /home/ubuntu/.pip/pip.conf')
    _execute_command_on_node(ip,
        'echo "index-url = ' + CONF["pip_index_url"] +'" >> /home/ubuntu/.pip/pip.conf')

    time.sleep(30)

    #download jenkins slave jar
    _execute_command_on_node(ip,
        'wget -P /tmp http://' + CONF["jenkins_host_port"] + '/jnlpJars/slave.jar')

    #launch agent
    _execute_command_on_node(ip,
        'screen -dmS agent java -jar /tmp/slave.jar' + ' -jnlpCredentials ' + CONF["jenkins_username"] + ":" + CONF["jenkins_password"]+ ' -jnlpUrl http://' + CONF["jenkins_jnlp_ip_port"] + '/computer/' + CONF["vm_name"] + '/slave-agent.jnlp')

def delete_vm():
    client = get_nova_client()
    servers = client.servers.list()

    current_name = CONF["vm_name"]

    for server in servers:
        if server.name == current_name:
            client.servers.delete(server.id)
            break

    jen = get_jenkins()
    jen.delete_node(current_name)

def cleanup_heat():
    current_name = sys.argv[2]
    client = get_heat_client()
    client.stacks.delete(current_name)

def cleanup():
    client = get_nova_client()
    servers = client.servers.list()
    current_name = sys.argv[2] 

    for server in servers:
        if current_name in server.name :
            print server.name
            fl_ips = client.floating_ips.findall(instance_id=server.id)
            for fl_ip in fl_ips:
                    client.floating_ips.delete(fl_ip.id)
            client.servers.delete(server.id)

def wait_vm_up(ip):
    while True:
        try:
            ret = _execute_command_on_node(ip, 'ls -l /')
            if ret == 0:
                return
            time.sleep(2)
        except:
            pass

def _setup_ssh_connection(host, ssh):
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        host,
        username=CONF["slave_username"],
        key_filename=CONF["private_key_path"]
    )
def _open_channel_and_execute(ssh, cmd):
    chan = ssh.get_transport().open_session()
    chan.exec_command(cmd)
    return chan.recv_exit_status()

def _execute_command_on_node(host, cmd):
    ssh = paramiko.SSHClient()
    try:
        _setup_ssh_connection(host, ssh)
        return _open_channel_and_execute(ssh, cmd)
    finally:
        ssh.close()

def main(argv):
    load_conf()

    if "create" in argv:
        boot_vm()

    if "checkpool" in argv:
        check_workers()

    if "delete" in argv:
        delete_vm()

    if "cleanup" in argv:
        cleanup()

    if "cleanup-heat" in argv:
        cleanup_heat()


if __name__ == "__main__":
    main(sys.argv[1:])
