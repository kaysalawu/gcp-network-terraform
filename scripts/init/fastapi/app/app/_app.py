import os
import socket
from fastapi import APIRouter, Request, HTTPException

router = APIRouter()

def get_ipv4_address():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(('8.8.8.8', 80))
            return s.getsockname()[0]
    except Exception:
        return "NotFound"

def get_ipv6_address():
    try:
        with socket.socket(socket.AF_INET6, socket.SOCK_DGRAM) as s:
            s.connect(('2001:4860:4860::8888', 80))
            return s.getsockname()[0]
    except Exception:
        return "NotFound"

hostname = socket.gethostname()
ipv4_address = get_ipv4_address()
ipv6_address = get_ipv6_address()

def generate_data_dict(app_name, request):
    return {
        'app': app_name,
        'hostname': os.getenv('HOST_HOSTNAME', 'Unknown'),
        'c-hostname': hostname,
        'ipv4': os.getenv('HOST_IPV4', ipv4_address),
        'ipv6': os.getenv('HOST_IPV6', ipv6_address),
        'remote-addr': request.client.host,
        'headers': dict(request.headers)
    }

@router.get("/")
async def default(request: Request):
    return generate_data_dict('SERVER', request)

@router.get("/path1")
async def path1(request: Request):
    return generate_data_dict('SERVER-PATH1', request)

@router.get("/path2")
async def path2(request: Request):
    return generate_data_dict('SERVER-PATH2', request)

@router.get("/healthz")
async def healthz(request: Request):
    # Example of adding specific logic for a particular endpoint if needed
    # allowed_hosts = ["healthz.az.corp"]
    # if request.client.host not in allowed_hosts:
    #     raise HTTPException(status_code=403, detail="Access denied")
    return "OK"
