import os
import socket
from fastapi import APIRouter, Request, HTTPException

router = APIRouter()

hostname = socket.gethostname()
ipv4_address = socket.gethostbyname(hostname)


def generate_data_dict(app_name, request):
    return {
        "app": app_name,
        "hostname": os.getenv("HOST_HOSTNAME", hostname),
        "server-ipv4": os.getenv("HOST_IPV4", ipv4_address),
        "remote-addr": request.client.host,
        "headers": dict(request.headers),
    }


@router.get("/")
async def default(request: Request):
    return generate_data_dict("Appy-HTTPS", request)


@router.get("/healthz")
async def healthz(request: Request):
    return "OK"
