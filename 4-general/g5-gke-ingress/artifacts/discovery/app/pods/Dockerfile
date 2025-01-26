FROM google/cloud-sdk:latest

RUN python -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
COPY main.py /app/main.py
WORKDIR /app

CMD ["python", "main.py"]
