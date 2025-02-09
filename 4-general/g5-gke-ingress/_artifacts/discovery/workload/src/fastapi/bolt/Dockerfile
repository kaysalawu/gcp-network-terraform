FROM python:3.12-alpine
WORKDIR /usr/local/bin
COPY tcp_listener.py /usr/local/bin/tcp_listener.py
RUN chmod +x /usr/local/bin/tcp_listener.py
CMD ["python3", "/usr/local/bin/tcp_listener.py"]
