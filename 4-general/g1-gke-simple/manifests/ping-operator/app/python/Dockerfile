# Dockerfile for the Ping Operator
FROM python:3.9-slim

RUN pip install kopf kubernetes
COPY ping_operator.py /app/ping_operator.py
WORKDIR /app

CMD ["kopf", "run", "/app/ping_operator.py"]
