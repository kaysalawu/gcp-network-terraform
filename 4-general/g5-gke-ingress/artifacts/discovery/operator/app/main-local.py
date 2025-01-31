import kopf
import kubernetes

# Initialize Kubernetes config
# use local kubeconfig when running locally
kubernetes.config.load_kube_config()


@kopf.on.create("example.com", "v1", "orchestras")
@kopf.on.update("example.com", "v1", "orchestras")
def on_orchestra_event(spec, **kwargs):
    orchestra_data = {
        "name": spec.get("name"),
        "region": spec.get("region"),
        "zone": spec.get("zone"),
        "project": spec.get("project"),
        "ingress": spec.get("ingress"),
    }

    print("Orchestra CR detected:")
    for key, value in orchestra_data.items():
        print(f"{key}: {value}")


@kopf.on.delete("example.com", "v1", "orchestras")
def on_orchestra_delete(meta, **kwargs):
    name = meta.get("name")
    print(f"Orchestra {name} has been deleted.")
