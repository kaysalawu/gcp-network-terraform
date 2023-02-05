import requests
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
    data_dict['headers'] = dict(request.headers)
    data_dict['remote'] = request.remote_addr
    return data_dict

if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=8080, debug = True)
