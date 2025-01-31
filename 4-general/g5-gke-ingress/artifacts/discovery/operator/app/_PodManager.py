import subprocess
import json


class PodManager:
    orchestra_name = "g5-spoke2-eu-cluster"
    zone = "europe-west2-b"
    project = "prj-spoke2-lab"

    @classmethod
    def get_context(cls):
        cmd = [
            "gcloud",
            "container",
            "clusters",
            "get-credentials",
            cls.orchestra_name,
            "--zone",
            cls.zone,
            "--project",
            cls.project,
        ]
        subprocess.run(cmd, check=True)

    @classmethod
    def get_pods(cls):
        cmd = ["kubectl", "get", "pods", "-o", "json"]
        result = subprocess.check_output(cmd, text=True)
        return json.loads(result)

    @classmethod
    def format_pod_info(cls, pods):
        formatted_pods = []
        for pod in pods["items"]:
            name = pod["metadata"]["name"]
            pod_ip = pod["status"].get("podIP", "No IP assigned")
            host_ip = pod["status"].get("hostIP", "No Host IP assigned")
            phase = pod["status"].get("phase", "Unknown")
            formatted_pods.append(
                {"name": name, "podIP": pod_ip, "hostIP": host_ip, "phase": phase}
            )
        return formatted_pods
