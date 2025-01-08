FROM python:3.9-slim

RUN pip install fastapi uvicorn kubernetes
COPY control_plane.py /app/control_plane.py
WORKDIR /app

CMD ["python", "control_plane.py"]
