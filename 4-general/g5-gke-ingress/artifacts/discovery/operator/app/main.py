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
from transitions.extensions import GraphMachine


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

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(funcName)s - %(message)s",
)
logger = logging.getLogger(__name__)
logging.getLogger("transitions.core").setLevel(logging.WARNING)


def initialize_kubernetes():
    global project_id, private_dns_zone

    try:
        # use in-cluster kubeconfig when running in the cluster
        config.load_incluster_config()
    except:
        # use local kubeconfig when running locally
        config.load_kube_config()

    # Project is required to fetch the private DNS zone.
    project_id = get_current_project_id()
    logger.info(f"Project ID: {project_id}")

    # In this example, we are fetching DNS zones with a search string = "private".
    # This is our private DNS zone used to register the endpoints discovered.
    private_dns_zone = get_dns_zone(project_id, "private")
    logger.info(f"Private DNS zone: {private_dns_zone}")


class OrchestraStateMachine:
    states = [
        "idle",
        "scanning",
        "updating_cr",
        "reconciling_dns",
        "deleting_dns",
        "completed",
        "error",
    ]

    def __init__(self, orchestra_name, cluster, project, region=None, zone=None):
        self.orchestra_name = orchestra_name
        self.cluster = cluster
        self.project = project
        self.region = region
        self.zone = zone
        self.pod_info = []

        self.machine = GraphMachine(
            model=self,
            states=OrchestraStateMachine.states,
            graph_engine="graphviz",
            initial="idle",
            transitions=[
                {"trigger": "start_scan", "source": "idle", "dest": "scanning"},
                {"trigger": "finish_scan", "source": "scanning", "dest": "updating_cr"},
                {
                    "trigger": "update_cr",
                    "source": "updating_cr",
                    "dest": "reconciling_dns",
                },
                {
                    "trigger": "finish_reconcile",
                    "source": "reconciling_dns",
                    "dest": "completed",
                },
                {"trigger": "start_delete", "source": "idle", "dest": "deleting_dns"},
                {
                    "trigger": "finish_delete",
                    "source": "deleting_dns",
                    "dest": "completed",
                },
                {"trigger": "error_occurred", "source": "*", "dest": "error"},
            ],
        )

    def scan_pods(self):
        self.start_scan()
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Scanning pods")
        pod_manager = PodManager(
            self.orchestra_name, self.cluster, self.project, self.zone, self.region
        )
        pod_manager.set_context()
        pods = pod_manager.get_pods()
        self.pod_info = pod_manager.format_pod_info(pods)
        pod_manager.unset_context()
        logger.info(
            f"[{self.orchestra_name}] State: {self.state} -> Found [{len(self.pod_info)}] pods"
        )
        self.finish_scan()

    def update_custom_resource(self):
        logger.info(f"[{self.orchestra_name}] State: {self.state} -> Updating CR")

        status_update = {
            "state": "Updated",
            "endpoints": list(self.pod_info),
        }

        api_instance = client.CustomObjectsApi()

        try:
            api_instance.patch_namespaced_custom_object(
                group="example.com",
                version="v1",
                namespace="default",
                plural="orchestras",
                name=self.orchestra_name,
                body={"status": status_update},
            )
            logger.info(f"[{self.orchestra_name}] State: {self.state} CR updated")
            self.update_cr()
        except client.exceptions.ApiException as e:
            logger.error(f"[{self.orchestra_name}] Failed to update CR: {e}")
            self.error_occurred()

    def reconcile_dns(self):
        logger.info(
            f"[{self.orchestra_name}] State: {self.state} -> Checking existing DNS records"
        )
        existing_records = get_existing_dns_a_records(
            project_id, private_dns_zone, self.orchestra_name
        )
        logger.info(
            f"[{self.orchestra_name}] Found [{len(existing_records)}] DNS records"
        )

        active_pod_dns_records = set()
        try:
            for pod in self.pod_info:
                pod_name = pod["podName"]
                pod_ip = pod["podIp"]
                create_private_dns_a_record(
                    project_id, private_dns_zone, self.orchestra_name, pod_name, pod_ip
                )
                active_pod_dns_records.add(
                    f"{pod_name}-{self.orchestra_name}.{private_dns_zone[0]['dns_name']}"
                )
        except (KeyError, TypeError) as e:
            logger.error(f"Error processing pod info for {self.orchestra_name}: {e}")
            self.error_occurred()
            return

        for record in existing_records:
            if record["name"] not in active_pod_dns_records:
                delete_private_dns_a_record(
                    project_id,
                    private_dns_zone,
                    self.orchestra_name,
                    record["name"].split(".")[0],
                    record["rrdatas"][0],
                )
                logger.info(
                    f"[{self.orchestra_name}] Deleted stale DNS record: {record['name']}"
                )

        self.finish_reconcile()

    def delete_dns_records(self):
        self.start_delete()
        logger.info(
            f"[{self.orchestra_name}] State: {self.state} -> Deleting DNS records"
        )
        existing_records = get_existing_dns_a_records(
            project_id, private_dns_zone, self.orchestra_name
        )

        for record in existing_records:
            delete_private_dns_a_record(
                project_id,
                private_dns_zone,
                self.orchestra_name,
                record["name"].split(".")[0],
                record["rrdatas"][0],
            )
            logger.info(f"[{self.orchestra_name}] Deleted DNS record: {record['name']}")

        self.finish_delete()

    def generate_state_diagram(self, output_file="state_diagram.png"):
        graph = self.machine.get_graph()

        graph.attr(rankdir="TB")  # "TB" for Top-Bottom layout, "LR" for Left-Right
        graph.attr(size="6,6")  # Adjust width and height
        graph.attr(dpi="600")  # Set high resolution for clarity

        graph.draw(output_file, prog="dot")
        logger.info(f"State diagram saved as {output_file}")


def process_orchestra(orchestra_name, cluster, project, region, zone):
    orchestra = OrchestraStateMachine(orchestra_name, cluster, project, region, zone)
    orchestra.scan_pods()
    orchestra.update_custom_resource()
    orchestra.reconcile_dns()


# Process all orchestra CRs
def process_all_orchestras():
    cmd = ["kubectl", "get", "orchestras.example.com", "-o", "json"]
    result = subprocess.check_output(cmd, text=True)
    crs = json.loads(result).get("items", [])

    cr_names = [cr.get("metadata", {}).get("name") for cr in crs]
    logger.info(f"CRs Found: {cr_names}")

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

        thread = threading.Thread(
            target=process_orchestra,
            args=(orchestra_name, cluster, project, region, zone),
        )
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()


def endpoints_scanner():
    logger.info("Initializing pod scanner...")
    while True:
        process_all_orchestras()
        time.sleep(20)


@kopf.on.create("example.com", "v1", "orchestras")
def on_orchestra_create(spec, meta, **kwargs):
    orchestra_name = meta.get("name", "unknown")
    cluster = spec.get("cluster")
    project = spec.get("project")
    region = spec.get("region")
    zone = spec.get("zone")

    logger.info(f"Orchestra CREATE: {orchestra_name}.")
    process_orchestra(orchestra_name, cluster, project, region, zone)


@kopf.on.update("example.com", "v1", "orchestras")
def on_orchestra_update(spec, meta, **kwargs):
    orchestra_name = meta.get("name", "unknown")
    cluster = spec.get("cluster")
    project = spec.get("project")
    region = spec.get("region")
    zone = spec.get("zone")

    logger.info(f"Orchestra UPDATE: {orchestra_name}")
    process_orchestra(orchestra_name, cluster, project, region, zone)


@kopf.on.delete("example.com", "v1", "orchestras")
def on_orchestra_delete(meta, **kwargs):
    orchestra_name = meta.get("name")

    logger.info(f"Orchestra DELETE: {orchestra_name}")
    orchestra = OrchestraStateMachine(orchestra_name, "", "", "", "")
    orchestra.delete_dns_records()


@kopf.on.startup()
def start_scanner(**kwargs):
    initialize_kubernetes()
    thread = threading.Thread(target=endpoints_scanner, daemon=True)
    thread.start()
