import subprocess
import json
import time
from datetime import datetime
from fastapi import FastAPI
import threading
from _PodManager import PodManager

# Pod is configured with a service account that has workload identity
# linked to a service account in the ingress project, and has roles
# roles/container.admin role to all target workload clusters.
# Context to the workload cluster works with the service account.

app = FastAPI()


def endpoints_scanner():
    print("[LOG] Initializing pod scanner...")
    PodManager.get_context()
    while True:
        pods = PodManager.get_pods()
        formatted_pods = PodManager.format_pod_info(pods)
        timestamp = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S")
        print({"timestamp": timestamp, "pods": formatted_pods})
        time.sleep(10)


@app.get("/scan")
def get_pods_endpoint():
    PodManager.get_context()
    pods = PodManager.get_pods()
    formatted_pods = PodManager.format_pod_info(pods)
    timestamp = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S")
    return {"timestamp": timestamp, "pods": formatted_pods}


thread = threading.Thread(target=endpoints_scanner, daemon=True)
thread.start()
print("[LOG] Continuous pod logging thread started.")
