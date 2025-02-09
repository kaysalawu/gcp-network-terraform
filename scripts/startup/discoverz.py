import os
import json
import requests
import urllib.request
from socket import timeout

response = urllib.request.urlopen("https://www.googleapis.com/discovery/v1/apis")
content = response.read()
data = json.loads(content.decode("utf8"))
googleapis = data["items"]
reachable = []
unreachable = []
print("\n scanning all api endpoints ...\n")
for api in googleapis:
    name = api["name"]
    version = api["version"]
    title = api["title"]
    url = "https://" + name + ".googleapis.com/generate_204"
    try:
        r = requests.get(url, timeout=1)
        if r.status_code == 204:
            reachable.append([r.status_code, name, url])
            print("{} - {:<26s} {:<10s} {}".format(r.status_code, name, version, url))
        else:
            unreachable.append([r.status_code, name, url])
            print("{} - {:<26s} {:<10s} {}".format(r.status_code, name, version, url))
    except Exception as e:
        print("{} - {:<26s} {:<10s} {}".format(r.status_code, name, version, url))
        unreachable.append(["err", name, url])
print("\n reachable api endpoints ...\n")
for code, name, url in sorted(reachable):
    print("{} - {:<26s} {:<10s} {}".format(code, name, version, url))
print("\n unreachable api endpoints ...\n")
for code, name, url in sorted(unreachable):
    print("{} - {:<26s} {:<10s} {}".format(code, name, version, url))
