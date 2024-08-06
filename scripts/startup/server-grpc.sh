#! /bin/bash

set -e
apt-get update -y
apt-get install -y openjdk-11-jdk-headless
curl -L https://github.com/grpc/grpc-java/archive/v1.37.0.tar.gz | tar -xz
cd grpc-java-1.37.0/examples/example-hostname
../gradlew --no-daemon installDist
# Server listens on 50051
systemd-run ./build/install/hostname-server/bin/hostname-server
