import kopf
from kubernetes import config
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
try:
    # use in-cluster kubeconfig when running in the cluster
    config.load_incluster_config()
except:
    # use local kubeconfig when running locally
    config.load_kube_config()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def scan_pods(name, cluster, project, region=None, zone=None):
    pod_manager = PodManager(name, cluster, project, zone, region)
    pod_manager.get_context()
    pods = pod_manager.get_pods()
    formatted_pods = pod_manager.format_pod_info(pods)
    timestamp = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S")
    logger.info({"timestamp": timestamp, "pods": formatted_pods})


def endpoints_scanner():
    logger.info("[LOG] Initializing pod scanner...")
    while True:
        logger.info("[LOG] Fetching orchestras CRs...")
        cmd = ["kubectl", "get", "orchestras.example.com", "-o", "json"]
        result = subprocess.check_output(cmd, text=True)
        crs = json.loads(result).get("items", [])

        threads = []
        for cr in crs:
            spec = cr.get("spec", {})
            name = cr.get("metadata").get("name")
            cluster = spec.get("cluster")
            project = spec.get("project")
            region = spec.get("region")
            zone = spec.get("zone")

            if not project or not cluster:
                continue

            logger.info(f"[LOG] Processing CR: {cr.get('metadata').get('name')}")

            thread = threading.Thread(
                target=scan_pods, args=(name, cluster, project, region, zone)
            )
            threads.append(thread)
            thread.start()

        for thread in threads:
            thread.join()

        time.sleep(30)


@app.get("/scan")
def get_pods_endpoint():
    cmd = ["kubectl", "get", "orchestras.example.com", "-o", "json"]
    result = subprocess.check_output(cmd, text=True)
    crs = json.loads(result).get("items", [])

    threads = []
    for cr in crs:
        spec = cr.get("spec", {})
        cluster = spec.get("cluster")
        project = spec.get("project")
        region = spec.get("region")
        zone = spec.get("zone")

        if not project or not cluster:
            continue

        thread = threading.Thread(
            target=scan_pods, args=(cluster, project, zone, region)
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
        "cluster": spec.get("cluster"),
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


@kopf.on.startup()
def start_scanner(**kwargs):
    thread = threading.Thread(target=endpoints_scanner, daemon=True)
    thread.start()
