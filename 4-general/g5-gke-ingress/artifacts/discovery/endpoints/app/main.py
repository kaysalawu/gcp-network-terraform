import subprocess
import json
import time


# Pod is configured with a service account that has workload identity
# linked to a service account in the ingress project, and has roles
# roles/container.admin role to all target workload clusters.
# Context to the workload cluster works with the service account.


def get_context():
    cmd = [
        "gcloud",
        "container",
        "clusters",
        "get-credentials",
        "g5-spoke2-eu-cluster",
        "--zone",
        "europe-west2-b",
        "--project",
        "prj-spoke2-lab",
    ]
    subprocess.run(cmd, check=True)


def get_pods():
    cmd = ["kubectl", "get", "pods", "-o", "json"]
    result = subprocess.check_output(cmd, text=True)
    return json.loads(result)


def format_pod_info(pods):
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


if __name__ == "__main__":
    N = 10
    get_context()
    while True:
        pods = get_pods()
        formatted_pods = format_pod_info(pods)
        print(json.dumps(formatted_pods, indent=2))
        time.sleep(N)
