import subprocess
import json
import logging
from kubernetes import config

logger = logging.getLogger(__name__)

"""
=========================================================================
This module sets up a PodManager class that is used to interact with
external kubernetes clusters. It sets the context using args received from
custom resource for each external cluster. The context must be reset back
to the in_cluster_config or local (kube_config) after the operation is done.
=========================================================================
"""


class PodManager:
    def __init__(self, orchestra_name, cluster, project, region=None, zone=None):
        if not zone and not region:
            raise ValueError("Either zone or region must be specified.")
        self.orchestra_name = orchestra_name
        self.cluster = cluster
        self.project = project
        self.zone = zone
        self.region = region

    def set_context(self):
        cmd = [
            "gcloud",
            "container",
            "clusters",
            "get-credentials",
            self.cluster,
            "--project",
            self.project,
        ]
        if self.zone:
            cmd.extend(["--zone", self.zone])
        else:
            cmd.extend(["--region", self.region])

        subprocess.run(cmd, check=True)
        context = subprocess.check_output(
            ["kubectl", "config", "current-context"], text=True
        ).strip()
        logger.info(f"Context switch: -> {context}")

    def unset_context(self):
        subprocess.run(["kubectl", "config", "unset", "current-context"], check=True)
        try:
            config.load_incluster_config()
            logger.info("Context switch: -> in-cluster")
        except:
            config.load_kube_config()
            logger.info("Context switch: -> local")

    def get_pods(self):
        cmd = ["kubectl", "get", "pods", "-o", "json"]
        result = subprocess.check_output(cmd, text=True)
        return json.loads(result)

    def format_pod_info(self, pods):
        formatted_pods = []
        for pod in pods["items"]:
            name = pod["metadata"]["name"]
            pod_ip = pod["status"].get("podIP", "No IP assigned")
            host_ip = pod["status"].get("hostIP", "No Host IP assigned")
            phase = pod["status"].get("phase", "Unknown")
            formatted_pods.append(
                {"podName": name, "podIp": pod_ip, "hostIp": host_ip, "phase": phase}
            )
        return formatted_pods
