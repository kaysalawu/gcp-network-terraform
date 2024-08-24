import requests
from flask import Flask, request
app = Flask(__name__)

@app.route("/")
def flasky():
    return "Try paths - /public or /private"

@app.route("/public")
def public():
    url = '${APP_TARGET1}'
    resp = requests.get(url)
    try:
        data = resp.json()
    except:
        data = 'error!'
    env_dict = {}
    request_dict = {}
    data_dict = {}
    env_dict['app'] = '${APP_NAME}'
    env_dict['env'] = 'PUBLIC'
    request_dict['remote addr'] = request.remote_addr
    request_dict['headers'] = dict(request.headers)
    request_dict['probe'] = data
    data_dict['environ'] = env_dict
    data_dict['request'] = request_dict
    return data_dict

@app.route("/private")
def private():
    url = '${APP_TARGET2}'
    resp = requests.get(url)
    try:
        data = resp.json()
    except:
        data = 'error!'
    env_dict = {}
    request_dict = {}
    data_dict = {}
    env_dict['app'] = '${APP_NAME}'
    env_dict['env'] = 'PRIVATE'
    request_dict['remote addr'] = request.remote_addr
    request_dict['headers'] = dict(request.headers)
    request_dict['probe'] = data
    data_dict['environ'] = env_dict
    data_dict['request'] = request_dict
    return data_dict
if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=${CONTAINER_PORT}, debug = True)
