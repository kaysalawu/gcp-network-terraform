FROM python:3.9-slim

RUN python -m venv /opt/venv \
    && . /opt/venv/bin/activate \
    && pip install --no-cache-dir fastapi uvicorn kubernetes pydantic

ENV PATH="/opt/venv/bin:$PATH"
COPY ping_api.py /app/ping_api.py
WORKDIR /app

CMD ["uvicorn", "ping_api:app", "--host", "0.0.0.0", "--port", "8080"]
