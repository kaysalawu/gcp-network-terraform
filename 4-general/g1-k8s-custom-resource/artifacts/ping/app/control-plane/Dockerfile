FROM python:3.9-slim

RUN pip install fastapi uvicorn kubernetes
COPY control_plane.py /app/control_plane.py
WORKDIR /app

CMD ["uvicorn", "control_plane:app", "--host", "0.0.0.0", "--port", "9000"]
