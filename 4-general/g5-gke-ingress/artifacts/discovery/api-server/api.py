from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from kubernetes import client, config
import uuid

# Initialize FastAPI app
app = FastAPI()

# Load Kubernetes configuration (use load_incluster_config() if running in-cluster)
config.load_incluster_config()


# Define the request model
class OrchestraRequest(BaseModel):
    name: str = None
    ingress: str
    project: str
    region: str = None
    zone: str = None

    class Config:
        schema_extra = {
            "example": {
                "name": "test-orchestra",
                "ingress": "ingress-001",
                "project": "prj-spoke2-lab",
                "region": "europe-west2",
                "zone": None,
            }
        }


# Endpoint to create an Orchestra CR
@app.post("/api/create_orchestra")
async def create_orchestra(orchestra_request: OrchestraRequest):
    resource_name = orchestra_request.name or f"orchestra-{uuid.uuid4()}"

    if not orchestra_request.region and not orchestra_request.zone:
        raise HTTPException(
            status_code=400, detail="Either region or zone must be specified."
        )

    # Kubernetes API instance
    api_instance = client.CustomObjectsApi()

    # Orchestra CR definition
    orchestra_resource = {
        "apiVersion": "example.com/v1",
        "kind": "Orchestra",
        "metadata": {"name": resource_name},
        "spec": {
            "ingress": orchestra_request.ingress,
            "project": orchestra_request.project,
            "region": orchestra_request.region,
            "zone": orchestra_request.zone,
        },
    }

    try:
        # Create the Orchestra CR in the Kubernetes cluster
        api_instance.create_namespaced_custom_object(
            group="example.com",
            version="v1",
            namespace="default",
            plural="orchestras",
            body=orchestra_resource,
        )
        return {"status": "success", "name": resource_name}
    except client.exceptions.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error creating resource: {e}")


# Endpoint to update an Orchestra CR
@app.put("/api/update_orchestra/{name}")
async def update_orchestra(name: str, orchestra_request: OrchestraRequest):
    api_instance = client.CustomObjectsApi()

    try:
        # Get existing resource
        existing_resource = api_instance.get_namespaced_custom_object(
            group="example.com",
            version="v1",
            namespace="default",
            plural="orchestras",
            name=name,
        )

        # Update spec
        existing_resource["spec"]["ingress"] = orchestra_request.ingress
        existing_resource["spec"]["project"] = orchestra_request.project
        existing_resource["spec"]["region"] = orchestra_request.region
        existing_resource["spec"]["zone"] = orchestra_request.zone

        # Apply the update
        api_instance.replace_namespaced_custom_object(
            group="example.com",
            version="v1",
            namespace="default",
            plural="orchestras",
            name=name,
            body=existing_resource,
        )
        return {"status": "success", "message": f"Resource {name} updated"}
    except client.exceptions.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error updating resource: {e}")


# Endpoint to delete an Orchestra CR
@app.delete("/api/delete_orchestra/{name}")
async def delete_orchestra(name: str):
    api_instance = client.CustomObjectsApi()
    try:
        # Delete the Orchestra CR
        api_instance.delete_namespaced_custom_object(
            group="example.com",
            version="v1",
            namespace="default",
            plural="orchestras",
            name=name,
        )
        return {"status": "success", "message": f"Resource {name} deleted"}
    except client.exceptions.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error deleting resource: {e}")


# To run the app:
# uvicorn orchestra_api:app --host 0.0.0.0 --port 8000
