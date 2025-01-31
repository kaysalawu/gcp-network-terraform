FROM python:3.9-slim

ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

COPY requirements.txt .

RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

COPY operator.py /app/

CMD ["kopf", "run", "/app/operator.py"]
