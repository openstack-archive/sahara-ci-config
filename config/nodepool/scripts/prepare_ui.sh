#!/bin/bash -x

sudo ufw disable
#sudo mkdir /opt/firefox
#sudo chmod 777 /opt/firefox
#cd /opt/firefox
#wget http://ftp.mozilla.org/pub/mozilla.org/firefox/releases/24.0/linux-x86_64/en-US/firefox-24.0.tar.bz2
#sudo tar xf firefox-24.0.tar.bz2
#sudo ln -s /opt/firefox/firefox/firefox /usr/sbin/firefox
#sudo chmod -R 755 /opt/firefox
#sudo chown -R jenkins:jenkins /opt/firefox

#Repository for Openstack Dashboard
#sudo add-apt-repository cloud-archive:havana -y

sudo add-apt-repository ppa:openstack-ubuntu-testing/icehouse -y
sudo apt-get update
sudo apt-get install libstdc++5 xvfb nodejs openstack-dashboard xserver-xorg -y
/usr/bin/yes | sudo pip install lesscpy mox
sudo iptables -F
sudo sed -i "s/'openstack_dashboard'/'saharadashboard',\n    'openstack_dashboard'/g" /usr/share/openstack-dashboard/openstack_dashboard/settings.py
sudo su -c "echo \"HORIZON_CONFIG['dashboards'] += ('sahara',)\" >> /usr/share/openstack-dashboard/openstack_dashboard/settings.py"
sudo sed -i "s/#from horizon.utils import secret_key/from horizon.utils import secret_key/g" /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.py
sudo sed -i "s/#SECRET_KEY = secret_key.generate_or_read_from_file(os.path.join(LOCAL_PATH, '.secret_key_store'))/SECRET_KEY = secret_key.generate_or_read_from_file(os.path.join(LOCAL_PATH, '.secret_key_store'))/g" /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.py
sudo sed -i "s/OPENSTACK_HOST = \"127.0.0.1\"/OPENSTACK_HOST = \"172.18.168.42\"/g" /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.py
sudo su -c 'echo -e "SAHARA_USE_NEUTRON = True" >> /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.py'
sudo su -c 'echo -e "AUTO_ASSIGNMENT_ENABLED = False" >> /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.py'
sudo su -c 'echo -e "SAHARA_URL = \"http://127.0.0.1:8386/v1.1\"" >> /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.py'
sudo sed -i "s/Require all granted/Allow from all/g" /etc/apache2/conf.d/openstack-dashboard.conf
sudo sed -i "s/COMPRESS_OFFLINE = True/COMPRESS_OFFLINE = False/g" /usr/share/openstack-dashboard/openstack_dashboard/local/local_settings.py
sudo rm /usr/share/openstack-dashboard/openstack_dashboard/local/ubuntu_theme.py
#sudo pip uninstall Django -y
#sudo pip install Django==1.5.1
sudo service apache2 stop
#wget http://sourceforge.net/projects/ubuntuzilla/files/mozilla/apt/pool/main/f/firefox-mozilla-build/firefox-mozilla-build_24.0-0ubuntu1_amd64.deb/download -O firefox24.deb
curl http://172.18.87.221/mirror/firefox24.deb > firefox24.deb
sudo dpkg -i firefox24.deb
#sudo dd if=/dev/zero of=/swapfile1 bs=1024 count=4194304
#sudo mkswap /swapfile1
#sudo chmod 0600 /swapfile1
#sudo swapon /swapfile1
#sudo su -c 'echo -e "/swapfile1 swap swap defaults 0 0" >> /etc/fstab'

sync
sleep 10
