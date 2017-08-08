Preparing
=========

1. Install ansible http://docs.ansible.com/ansible/latest/intro_installation.html
2. Install ansible roles

.. sourcecode:: console

    $ ansible-galaxy install geerlingguy.jenkins
..

3. Put private key for nodepool to `roles/nodepool/templates/id_rsa`
4. Put private key for zuul to `roles/zuul/templates/gerrit`

How to use
==========

1. Run

.. sourcecode:: console

    $ ansible-playbook -s site.yml

..
