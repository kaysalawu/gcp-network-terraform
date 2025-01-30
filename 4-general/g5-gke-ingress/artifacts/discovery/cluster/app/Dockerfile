FROM google/cloud-sdk:latest

RUN apt-get update && \
    apt-get install -y python3-venv && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY requirements.txt .

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

COPY main.py _PodManager.py /app/

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
