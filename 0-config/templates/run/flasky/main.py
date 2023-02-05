import requests
from flask import Flask, request
app = Flask(__name__)

@app.route("/")
def default():
    data_dict = {}
    data_dict['headers'] = dict(request.headers)
    data_dict['remote addr'] = request.remote_addr
    return data_dict

if __name__ == "__main__":
    app.run(host= '0.0.0.0', port=8080, debug = True)
