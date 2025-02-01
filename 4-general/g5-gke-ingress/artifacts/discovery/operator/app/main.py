import kopf
from kubernetes import config, client
import logging
import subprocess
import json
import time
from datetime import datetime
import threading
from _PodManager import PodManager


"""
=========================================================================
The ingress cluster hosts the operator deployment running this code.
The deployment is configured with a k8s service account that has workload
identity linked to a GCE service account in the local project.
The GCE service account has project roles/container.admin role for access
to target external workload clusters.

The operator knows which external clusters to scan for pods by reading
custom resources (CRs) of kind 'orchestras.example.com'. The CRs contain
the context information needed to switch to the target external cluster.

The operator switches context to each cluster, extracts pod information
and updates the CR status with the pod information.

A FastAPI endpoint is exposed to trigger the scan manually. The endpoint
fetches all CRs and scans the external clusters for pods.
=========================================================================
"""

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


# Set the context to the target external cluster and fetch pod information.
def scan_pods(name, cluster, project, region=None, zone=None):
    pod_manager = PodManager(name, cluster, project, zone, region)
    pod_manager.set_context()
    pods = pod_manager.get_pods()
    formatted_pods = pod_manager.format_pod_info(pods)
    pod_count = len(formatted_pods)
    timestamp = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S")
    logger.info(f"{pod_count} endpoints found: {timestamp}")
    pod_manager.unset_context()
    return formatted_pods


def process_all_orchestras():
    logger.info("[LOG] Fetching orchestras CRs...")
    cmd = ["kubectl", "get", "orchestras.example.com", "-o", "json"]
    result = subprocess.check_output(cmd, text=True)
    crs = json.loads(result).get("items", [])

    cr_names = [cr.get("metadata", {}).get("name") for cr in crs]
    logger.info(f"[LOG] CRs found: {cr_names}")

    api_instance = client.CustomObjectsApi()

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

        logger.info(f"[LOG] Processing CR: {name}")

        def process_cr():
            pod_info = scan_pods(name, cluster, project, region, zone)
            status_update = {"state": "Updated", "endpoints": pod_info}

            try:
                api_instance.patch_namespaced_custom_object(
                    group="example.com",
                    version="v1",
                    namespace="default",
                    plural="orchestras",
                    name=name,
                    body={"status": status_update},
                )
                logger.info(f"[LOG] Updated CR status for {name}")
            except client.exceptions.ApiException as e:
                logger.error(f"[LOG] Error updating status for {name}: {e}")

        thread = threading.Thread(target=process_cr)
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()


def endpoints_scanner():
    logger.info("[LOG] Initializing pod scanner...")
    while True:
        process_all_orchestras()
        time.sleep(30)


@kopf.on.create("example.com", "v1", "orchestras")
def on_orchestra_create(spec, meta, **kwargs):
    cluster = spec.get("cluster", "unknown")
    name = meta.get("name", "unknown")
    logger.info(f"Cluster {cluster} (CR: {name}) has been **created**.")
    process_all_orchestras()


@kopf.on.update("example.com", "v1", "orchestras")
def on_orchestra_update(spec, meta, **kwargs):
    cluster = spec.get("cluster", "unknown")
    name = meta.get("name", "unknown")
    logger.info(f"Cluster {cluster} (CR: {name}) has been **updated**.")
    process_all_orchestras()


@kopf.on.delete("example.com", "v1", "orchestras")
def on_orchestra_delete(meta, **kwargs):
    name = meta.get("name")
    logger.info(f"Orchestra {name} has been deleted.")


@kopf.on.startup()
def start_scanner(**kwargs):
    thread = threading.Thread(target=endpoints_scanner, daemon=True)
    thread.start()
