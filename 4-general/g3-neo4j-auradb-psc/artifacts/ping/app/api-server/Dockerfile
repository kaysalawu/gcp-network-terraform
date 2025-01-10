FROM python:3.9-slim

RUN pip install fastapi uvicorn kubernetes pydantic
COPY ping_api.py /app/ping_api.py
WORKDIR /app

CMD ["uvicorn", "ping_api:app", "--host", "0.0.0.0", "--port", "8080"]
