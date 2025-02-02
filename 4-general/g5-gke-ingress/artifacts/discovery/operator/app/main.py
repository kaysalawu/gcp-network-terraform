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
=========================================================================
"""

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


# Set the context to the target external cluster and fetch pod information.
def scan_pods(orchestra_name, cluster, project, region=None, zone=None):
    pod_manager = PodManager(orchestra_name, cluster, project, zone, region)
    pod_manager.set_context()
    pods = pod_manager.get_pods()
    formatted_pods = pod_manager.format_pod_info(pods)
    pod_count = len(formatted_pods)
    timestamp = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S")
    logger.info(f"Endpoints: Found {pod_count} ({timestamp})")
    pod_manager.unset_context()
    return formatted_pods


# Reconcile DNS records to ensure only active pods have DNS entries.
def reconcile_dns(orchestra_name, pod_info):
    # Fetch all existing A records in the private DNS zone.
    existing_records = get_existing_dns_a_records(
        project_id, private_dns_zone, orchestra_name
    )

    # Create or update DNS for active pods, and track active records.
    active_pod_dns_records = set()
    for pod in pod_info:
        pod_name = pod["podName"]
        pod_ip = pod["podIp"]
        create_private_dns_a_record(
            project_id, private_dns_zone, orchestra_name, pod_name, pod_ip
        )
        active_pod_dns_records.add(
            f"{pod_name}-{orchestra_name}.{private_dns_zone[0]['dns_name']}"
        )

    # Delete stale records (records that exist but aren't in the active pod list).
    for record in existing_records:
        record_name = record["name"]
        if orchestra_name in record_name and record_name not in active_pod_dns_records:
            logger.info(f"DNS Reconcile: Delete -> {record_name}")
            delete_private_dns_a_record(
                project_id,
                private_dns_zone,
                orchestra_name,
                pod_name,
                record["rrdatas"][0],
            )
        logger.info(f"DNS Reconcile: Skip -> {record_name}")


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
        orchestra_name = cr.get("metadata").get("name")
        cluster = spec.get("cluster")
        project = spec.get("project")
        region = spec.get("region")
        zone = spec.get("zone")

        if not project or not cluster:
            continue

        logger.info(f"[LOG] Processing CR: {orchestra_name}")

        def process_cr():
            pod_info = scan_pods(orchestra_name, cluster, project, region, zone)
            status_update = {"state": "Updated", "endpoints": pod_info}

            # Update the CR status with pod information
            try:
                api_instance.patch_namespaced_custom_object(
                    group="example.com",
                    version="v1",
                    namespace="default",
                    plural="orchestras",
                    name=orchestra_name,
                    body={"status": status_update},
                )
                logger.info(f"CR Update: Success! {orchestra_name}")
            except client.exceptions.ApiException as e:
                logger.error(f"CR Update: Failed! {orchestra_name}: {e}")

            # Reconcile DNS based on updated pod information.
            reconcile_dns(orchestra_name, pod_info)

        thread = threading.Thread(target=process_cr)
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()


def endpoints_scanner():
    logger.info("[LOG] Initializing pod scanner...")
    while True:
        process_all_orchestras()
        time.sleep(20)


@kopf.on.create("example.com", "v1", "orchestras")
def on_orchestra_create(spec, meta, **kwargs):
    orchestra_name = meta.get("name", "unknown")
    logger.info(f"Orchestra {orchestra_name} has been **created**.")
    process_all_orchestras()


@kopf.on.update("example.com", "v1", "orchestras")
def on_orchestra_update(spec, meta, **kwargs):
    orchestra_name = meta.get("name", "unknown")
    logger.info(f"Orchestra {orchestra_name} has been **updated**.")
    process_all_orchestras()


@kopf.on.delete("example.com", "v1", "orchestras")
def on_orchestra_delete(meta, **kwargs):
    orchestra_name = meta.get("name")
    logger.info(f"Orchestra {orchestra_name} has been deleted.")
    process_all_orchestras()


@kopf.on.startup()
def start_scanner(**kwargs):
    thread = threading.Thread(target=endpoints_scanner, daemon=True)
    thread.start()
