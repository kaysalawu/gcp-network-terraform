from kubernetes import client, config, watch
from fastapi import FastAPI
import threading

# Initialize Kubernetes config
# use local kubeconfig when running locally
config.load_kube_config()

# Kubernetes API instance
api_instance = client.CustomObjectsApi()

# Store resource states
resources_state = {}

# Initialize FastAPI
app = FastAPI()

@app.get("/resources")
def get_resources():
    return {"resources": resources_state}

def monitor_ping_resources():
    print("Started monitoring PingResource events...")  # Debug message
    watcher = watch.Watch()
    try:
        for event in watcher.stream(api_instance.list_namespaced_custom_object,
                                    group="example.com", version="v1",
                                    namespace="default", plural="pingresources", timeout_seconds=0):
            resource = event['object']
            event_type = event['type']
            resource_name = resource['metadata']['name']

            if event_type == "ADDED":
                resources_state[resource_name] = "created"
                print(f"Resource {resource_name} added.")
            elif event_type == "DELETED":
                resources_state.pop(resource_name, None)
                print(f"Resource {resource_name} deleted.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        print("Stopped monitoring PingResource events.")

# Start the Kubernetes watcher in a separate thread
thread = threading.Thread(target=monitor_ping_resources, daemon=True)
thread.start()
