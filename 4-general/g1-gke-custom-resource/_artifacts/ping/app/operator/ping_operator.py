import kopf
import kubernetes

# Initialize Kubernetes config
# use in-cluster kubeconfig when running in the cluster
kubernetes.config.load_incluster_config()

@kopf.on.create("example.com", "v1", "pingresources")
def on_create_pingresource(spec, patch, **kwargs):
    message = spec.get("message", "Ping")
    response = f"{message} - Pong"

    # Explicitly patch the status field with the response
    patch.status["response"] = response

@kopf.on.delete("example.com", "v1", "pingresources")
def on_delete_pingresource(meta, **kwargs):
    name = meta.get("name")
    print(f"PingResource {name} has been deleted.")
