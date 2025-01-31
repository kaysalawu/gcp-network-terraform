import kopf
import kubernetes
import logging
import subprocess
import json
import time
from datetime import datetime
from fastapi import FastAPI
import threading
from _PodManager import PodManager

# Pod is configured with a service account that has workload identity
# linked to a service account in the ingress project, and has
# roles/container.admin role for access to all target workload clusters.

app = FastAPI()

# Initialize Kubernetes config
# use in-cluster kubeconfig when running in the cluster
kubernetes.config.load_incluster_config()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def scan_pods(orchestra_name, project, zone=None, region=None):
    pod_manager = PodManager(orchestra_name, project, zone, region)
    pod_manager.get_context()
    pods = pod_manager.get_pods()
    formatted_pods = pod_manager.format_pod_info(pods)
    timestamp = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S")
    logger.info({"timestamp": timestamp, "pods": formatted_pods})


def endpoints_scanner():
    logger.info("[LOG] Initializing pod scanner...")
    while True:
        cmd = ["kubectl", "get", "orchestras.example.com", "-o", "json"]
        result = subprocess.check_output(cmd, text=True)
        crs = json.loads(result).get("items", [])

        threads = []
        for cr in crs:
            spec = cr.get("spec", {})
            orchestra_name = spec.get("name")
            project = spec.get("project")
            region = spec.get("region")
            zone = spec.get("zone")

            if not project or not orchestra_name:
                continue

            thread = threading.Thread(
                target=scan_pods, args=(orchestra_name, project, zone, region)
            )
            threads.append(thread)
            thread.start()

        for thread in threads:
            thread.join()

        time.sleep(10)


@app.get("/scan")
def get_pods_endpoint():
    cmd = ["kubectl", "get", "orchestras.example.com", "-o", "json"]
    result = subprocess.check_output(cmd, text=True)
    crs = json.loads(result).get("items", [])

    threads = []
    for cr in crs:
        spec = cr.get("spec", {})
        orchestra_name = spec.get("name")
        project = spec.get("project")
        region = spec.get("region")
        zone = spec.get("zone")

        if not project or not orchestra_name:
            continue

        thread = threading.Thread(
            target=scan_pods, args=(orchestra_name, project, zone, region)
        )
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()

    timestamp = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S")
    return {"timestamp": timestamp, "status": "Scan completed"}


@kopf.on.create("example.com", "v1", "orchestras")
@kopf.on.update("example.com", "v1", "orchestras")
def on_orchestra_event(spec, **kwargs):
    orchestra_data = {
        "name": spec.get("name"),
        "region": spec.get("region"),
        "zone": spec.get("zone"),
        "project": spec.get("project"),
        "ingress": spec.get("ingress"),
    }

    logger.info("Orchestra CR detected:")
    for key, value in orchestra_data.items():
        logger.info(f"{key}: {value}")


@kopf.on.delete("example.com", "v1", "orchestras")
def on_orchestra_delete(meta, **kwargs):
    name = meta.get("name")
    logger.info(f"Orchestra {name} has been deleted.")


scanner_thread = threading.Thread(target=endpoints_scanner, daemon=True)
scanner_thread.start()
