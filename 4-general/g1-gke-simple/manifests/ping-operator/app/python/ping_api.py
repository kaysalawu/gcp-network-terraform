from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from kubernetes import client, config
import uuid

# Initialize FastAPI app
app = FastAPI()

# Load Kubernetes configuration (use load_incluster_config() if running in-cluster)
config.load_kube_config()

# Define the request model
class PingResourceRequest(BaseModel):
    name: str = None
    message: str = "Ping"

# Endpoint to create a PingResource
@app.post("/api/create_ping")
async def create_ping(ping_request: PingResourceRequest):
    resource_name = ping_request.name or f"ping-{uuid.uuid4()}"
    message = ping_request.message

    # Kubernetes API instance
    api_instance = client.CustomObjectsApi()

    # PingResource definition
    ping_resource = {
        "apiVersion": "example.com/v1",
        "kind": "PingResource",
        "metadata": {"name": resource_name},
        "spec": {"message": message}
    }

    try:
        # Create the PingResource in the Kubernetes cluster
        api_instance.create_namespaced_custom_object(
            group="example.com",
            version="v1",
            namespace="default",
            plural="pingresources",
            body=ping_resource
        )
        return {"status": "success", "name": resource_name}
    except client.exceptions.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error creating resource: {e}")

# To run the app:
# uvicorn ping_api:app --reload
