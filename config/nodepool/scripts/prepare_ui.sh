#!/bin/bash -x

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
NETWORK=`ifconfig eth0 | awk -F ' *|:' '/inet addr/{print $4}' | awk -F . '{print $2}'`
if [ "$NETWORK" == "0" ]; then
    OPENSTACK_HOST="172.18.168.42"
else
    OPENSTACK_HOST="172.18.168.43"
fi

sudo apt-get install libstdc++5 nodejs xserver-xorg libffi-dev apache2 libapache2-mod-wsgi  -y
git clone https://github.com/openstack/horizon
cd horizon && sudo pip install -U -r requirements.txt
python manage.py compress --force
cp -r static/ openstack_dashboard/
cp openstack_dashboard/local/local_settings.py.example openstack_dashboard/local/local_settings.py
sudo sed -i "s/OPENSTACK_HOST = \"127.0.0.1\"/OPENSTACK_HOST = \"${OPENSTACK_HOST}\"/g" openstack_dashboard/local/local_settings.py
cd .. && sudo mv horizon /opt/
sudo chown -R www-data:www-data /opt/horizon
sudo su -c "echo '
<VirtualHost *:80>
    ServerName localhost
    WSGIScriptAlias / /opt/horizon/openstack_dashboard/wsgi/django.wsgi
    WSGIDaemonProcess horizon user=www-data group=www-data processes=3 threads=10
    Alias /static /opt/horizon/openstack_dashboard/static
    <Directory /opt/horizon/openstack_dashboard/wsgi>
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>' > /etc/apache2/conf.d/horizon"

sudo sed -i "s/'openstack_dashboard'/'saharadashboard',\n    'openstack_dashboard'/g" /opt/horizon/openstack_dashboard/settings.py
sudo su -c "echo \"HORIZON_CONFIG['dashboards'] += ('sahara',)\" >> /opt/horizon/openstack_dashboard/settings.py"
sudo sed -i "s/#from horizon.utils import secret_key/from horizon.utils import secret_key/g" /opt/horizon/openstack_dashboard/local/local_settings.py
sudo sed -i "s/#SECRET_KEY = secret_key.generate_or_read_from_file(os.path.join(LOCAL_PATH, '.secret_key_store'))/SECRET_KEY = secret_key.generate_or_read_from_file(os.path.join(LOCAL_PATH, '.secret_key_store'))/g" /opt/horizon/openstack_dashboard/local/local_settings.py
sudo sed -i "s/OPENSTACK_HOST = \"127.0.0.1\"/OPENSTACK_HOST = \"${OPENSTACK_HOST}\"/g" /opt/horizon/openstack_dashboard/local/local_settings.py
sudo su -c 'echo -e "SAHARA_USE_NEUTRON = True" >> /opt/horizon/openstack_dashboard/local/local_settings.py'
sudo su -c 'echo -e "AUTO_ASSIGNMENT_ENABLED = False" >> /opt/horizon/openstack_dashboard/local/local_settings.py'
sudo su -c 'echo -e "SAHARA_URL = \"http://127.0.0.1:8386/v1.1\"" >> /opt/horizon/openstack_dashboard/local/local_settings.py'
sudo su -c 'echo "COMPRESS_OFFLINE = True" >> /opt/horizon/openstack_dashboard/local/local_settings.py'

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
