from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from kubernetes import client, config
import uuid
import kubernetes

# Initialize FastAPI app
app = FastAPI()

# Initialize Kubernetes config
try:
    # use in-cluster kubeconfig when running in the cluster
    config.load_incluster_config()
except:
    # use local kubeconfig when running locally
    config.load_kube_config()


# Define the request model
class OrchestraRequest(BaseModel):
    name: str
    cluster: str
    ingress: str
    project: str
    region: str = None
    zone: str = None

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "name": "orch01",
                    "cluster": "g5-spoke2-eu-cluster",
                    "ingress": "ingress01",
                    "project": "prj-spoke2-lab",
                    "region": None,
                    "zone": "europe-west2-b",
                },
                {
                    "name": "orch02",
                    "cluster": "g5-spoke2-us-cluster",
                    "ingress": "ingress01",
                    "project": "prj-spoke2-lab",
                    "region": None,
                    "zone": "us-west2-b",
                },
            ]
        }
    }


# Endpoint to list all Orchestra CRs
@app.get("/api/list_orchestras")
async def list_orchestras():
    api_instance = client.CustomObjectsApi()
    try:
        resources = api_instance.list_namespaced_custom_object(
            group="example.com",
            version="v1",
            namespace="default",
            plural="orchestras",
        )
        return {"status": "success", "orchestras": resources.get("items", [])}
    except client.exceptions.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error listing resources: {e}")


# Endpoint to get a specific Orchestra CR
@app.get("/api/get_orchestra/{name}")
async def get_orchestra(name: str):
    api_instance = client.CustomObjectsApi()
    try:
        resource = api_instance.get_namespaced_custom_object(
            group="example.com",
            version="v1",
            namespace="default",
            plural="orchestras",
            name=name,
        )
        return {"status": "success", "orchestra": resource}
    except client.exceptions.ApiException as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving resource: {e}")


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
            "cluster": orchestra_request.cluster,
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
        existing_resource["spec"]["cluster"] = orchestra_request.cluster
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
