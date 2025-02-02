FROM python:3.12-alpine
WORKDIR /app
COPY . .
RUN pip install --verbose --no-cache-dir -r requirements.txt
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7474"]
