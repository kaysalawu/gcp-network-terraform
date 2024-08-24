#! /bin/bash

apt update
apt install -y wget python3-pip python3-dev
pip3 install Flask requests

mkdir /var/flaskapp
mkdir /var/flaskapp/flaskapp
mkdir /var/flaskapp/flaskapp/static
mkdir /var/flaskapp/flaskapp/templates

cat <<EOF > /var/flaskapp/flaskapp/__init__.py
import socket
from flask import Flask, request
app = Flask(__name__)
@app.route("/")
def default():
    hostname = socket.gethostname()
    address = socket.gethostbyname(hostname)
    data_dict = {}
    data_dict['name'] = hostname
    data_dict['address'] = address
    data_dict['remote'] = request.remote_addr
    data_dict['headers'] = dict(request.headers)
    return data_dict
if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=${PORT}, debug = True)
EOF

nohup python3 /var/flaskapp/flaskapp/__init__.py &
cat <<EOF > /var/tmp/startup.sh
nohup python3 /var/flaskapp/flaskapp/__init__.py &
EOF

echo "@reboot source /var/tmp/startup.sh" >> /var/tmp/crontab_flask.txt
crontab /var/tmp/crontab_flask.txt
