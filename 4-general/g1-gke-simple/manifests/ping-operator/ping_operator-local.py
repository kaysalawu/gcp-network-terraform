import kopf
import kubernetes

# use local kubeconfig when running locally
kubernetes.config.load_kube_config()

@kopf.on.create("example.com", "v1", "pingresources")
def on_create_pingresource(spec, patch, **kwargs):
    message = spec.get("message", "Ping")
    response = f"{message} - Pong"

    # Explicitly patch the status field with the response
    patch.status["response"] = response
