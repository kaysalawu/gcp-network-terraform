import subprocess
import json


class PodManager:
    def __init__(self, orchestra_name, project, zone=None, region=None):
        if not zone and not region:
            raise ValueError("Either zone or region must be specified.")
        self.orchestra_name = orchestra_name
        self.project = project
        self.zone = zone
        self.region = region

    def get_context(self):
        cmd = [
            "gcloud",
            "container",
            "clusters",
            "get-credentials",
            self.orchestra_name,
            "--project",
            self.project,
        ]
        if self.zone:
            cmd.extend(["--zone", self.zone])
        else:
            cmd.extend(["--region", self.region])

        subprocess.run(cmd, check=True)

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
                {"name": name, "podIP": pod_ip, "hostIP": host_ip, "phase": phase}
            )
        return formatted_pods
