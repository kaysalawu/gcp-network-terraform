FROM python:3.9-slim

RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --no-cache-dir fastapi uvicorn kubernetes

ENV PATH="/opt/venv/bin:$PATH"
COPY control_plane.py /app/control_plane.py
WORKDIR /app

CMD ["uvicorn", "control_plane:app", "--host", "0.0.0.0", "--port", "9000"]
