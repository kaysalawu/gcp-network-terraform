FROM google/cloud-sdk:latest

RUN apt-get update && \
    apt-get install -y python3-venv graphviz graphviz-dev && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY requirements.txt .

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

COPY main.py _PodManager.py utils/ /app/

CMD ["kopf", "run", "--all-namespaces", "/app/main.py"]
