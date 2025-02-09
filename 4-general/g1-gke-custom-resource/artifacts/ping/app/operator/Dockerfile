# Dockerfile for the Ping Operator
FROM python:3.9-slim

RUN python -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    pip install --no-cache-dir kopf kubernetes

ENV PATH="/opt/venv/bin:$PATH"
COPY ping_operator.py /app/ping_operator.py
WORKDIR /app

CMD ["kopf", "run", "--all-namespaces", "/app/ping_operator.py"]
