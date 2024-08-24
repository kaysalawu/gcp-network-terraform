#! /bin/bash

apt-get update
apt-get install apache2 -y
a2ensite default-ssl
a2enmod ssl
echo "VERTEX-AI" > /var/www/html/index.html
systemctl restart apache2'
