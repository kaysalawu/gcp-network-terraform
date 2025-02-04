import subprocess
import json
import logging
import tempfile
import os
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
    def __init__(self, state, orchestra_name, cluster, project, region=None, zone=None):
        if not zone and not region:
            raise ValueError("Either zone or region must be specified.")
        self.state = state
        self.orchestra_name = orchestra_name
        self.cluster = cluster
        self.project = project
        self.zone = zone
        self.region = region
        self.kubeconfig_path = None

    def set_context(self):
        # Create a temporary kubeconfig file for this instance
        kubeconfig_file = tempfile.NamedTemporaryFile(
            prefix=f"kubeconfig-{self.orchestra_name}-{self.cluster}-", delete=False
        )
        self.kubeconfig_path = kubeconfig_file.name
        kubeconfig_file.close()
        env = os.environ.copy()
        env["KUBECONFIG"] = self.kubeconfig_path
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
        subprocess.run(cmd, check=True, env=env)
        context = subprocess.check_output(
            ["kubectl", "config", "current-context"], text=True, env=env
        ).strip()
        logger.info(
            f"[{self.orchestra_name}] {self.state} -> set_context() -> {context}"
        )

    def unset_context(self):
        env = os.environ.copy()
        if self.kubeconfig_path:
            env["KUBECONFIG"] = self.kubeconfig_path
            subprocess.run(
                ["kubectl", "config", "unset", "current-context"], check=True, env=env
            )
            try:
                config.load_incluster_config()
                logger.info(
                    f"[{self.orchestra_name}] {self.state} -> unset_context() (in_cluster_config)"
                )
            except:
                config.load_kube_config()
                logger.info(
                    f"[{self.orchestra_name}] {self.state} -> unset_context() (local)"
                )
            os.remove(self.kubeconfig_path)
            self.kubeconfig_path = None

    def get_pods(self):
        env = os.environ.copy()
        if self.kubeconfig_path:
            env["KUBECONFIG"] = self.kubeconfig_path
        cmd = ["kubectl", "get", "pods", "-o", "json"]
        result = subprocess.check_output(cmd, text=True, env=env)
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
