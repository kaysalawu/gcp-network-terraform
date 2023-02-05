FROM debian:buster

RUN apt update -y
RUN apt install -y apt-utils python3-pip curl dnsutils vim
COPY requirements.txt .
RUN pip3 install -r requirements.txt

RUN cd /var
RUN if [ ! -d "flaskapp" ]; then mkdir flaskapp; fi
RUN cd flaskapp
RUN if [ ! -d "flaskapp" ]; then mkdir flaskapp; fi
RUN cd flaskapp
RUN mkdir static templates

COPY __init__.py /var/flaskapp/flaskapp/

ENTRYPOINT FLASK_APP=/var/flaskapp/flaskapp/__init__.py flask run --host=0.0.0.0 --port=80
