import kopf
from kubernetes import config, client
import logging
import subprocess
import json
import time
from datetime import datetime
import threading
from _PodManager import PodManager
from google.cloud import dns
from utils import *


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Kubernetes config
try:
    # use in-cluster kubeconfig when running in the cluster
    config.load_incluster_config()
except:
    # use local kubeconfig when running locally
    config.load_kube_config()

# Project is required to fetch the private DNS zone.
project_id = get_current_project_id()
logging.info(f"Project ID: {project_id}")


# In this example, we are fetching DNS zones with a search string = "private".
# This is our private DNS zone used to register the endpoints discovered.
private_dns_zone = get_dns_zone(project_id, "private")
logging.info(f"Private DNS zone: {private_dns_zone}")

create_private_dns_a_record(project_id, private_dns_zone, "test", "1.1.1.1")


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
    process_all_orchestras()


@kopf.on.startup()
def start_scanner(**kwargs):
    thread = threading.Thread(target=endpoints_scanner, daemon=True)
    thread.start()
