# Dockerfile for the Ping Operator
FROM python:3.9-slim

# Install dependencies
RUN pip install kopf kubernetes

# Copy the Operator code
COPY ping_operator.py /app/ping_operator.py

# Set the working directory
WORKDIR /app

# Run the Operator
CMD ["kopf", "run", "/app/ping_operator.py"]
