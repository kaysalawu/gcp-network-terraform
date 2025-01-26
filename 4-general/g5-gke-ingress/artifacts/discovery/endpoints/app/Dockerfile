FROM google/cloud-sdk:latest

RUN apt-get update && \
    apt-get install -y python3-venv && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt /tmp/requirements.txt

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt

COPY main.py /app/main.py
WORKDIR /app

CMD ["python", "main.py"]
