
import os
import json
import requests
import urllib.request
from flask import Flask, request

app = Flask(__name__)

# health check
@app.route('/healthz')
def healthz():
    return 'Pass'

# orange
@app.route("/")
def orange():
    env_dict = dict()
    request_dict = dict()
    data_dict = dict()

    # route config
    env_dict['env'] = 'PROD'
    env_dict['app'] = 'ORANGE'

    # request info
    request_dict['remote addr'] = request.remote_addr
    request_dict['remote user'] = request.remote_user
    request_dict['headers']     = dict(request.headers)

    # output data
    data_dict['environ'] = env_dict
    data_dict['request'] = request_dict
    return data_dict

if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=80, debug = True)
