FROM python:3.9-slim
ENV PYTHONUNBUFFERED True
WORKDIR /app
COPY . ./
RUN pip install -r requirements.txt
CMD exec gunicorn --bind :${TARGET_PORT} --workers 1 --threads 8 --timeout 0 main:app
