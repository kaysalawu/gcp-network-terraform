#! /bin/bash

apt update
apt install -y tcpdump fping dnsutils

set -e
export GRPC_XDS_BOOTSTRAP=/run/td-grpc-bootstrap.json
# Expose bootstrap variable to SSH connections
echo export GRPC_XDS_BOOTSTRAP=$GRPC_XDS_BOOTSTRAP | sudo tee /etc/profile.d/grpc-xds-bootstrap.sh
# Create the bootstrap file
curl -L https://storage.googleapis.com/traffic-director/td-grpc-bootstrap-0.11.0.tar.gz | tar -xz
./td-grpc-bootstrap-0.11.0/td-grpc-bootstrap \
-gcp-project-number ${TD_PROJECT_NUMBER} \
-vpc-network-name ${TD_NETWORK_NAME} \
| tee $GRPC_XDS_BOOTSTRAP

# playz
#-----------------------------------
curl -L https://github.com/fullstorydev/grpcurl/releases/download/v1.8.1/grpcurl_1.8.1_linux_x86_64.tar.gz | tar -xz
mv grpcurl /usr/local/bin/
cat <<EOF > /usr/local/bin/playz
%{ for target in TARGETS_GRPC ~}
echo ""
grpcurl --plaintext -d '"'{"'"name"'": "'"world"'"}'"' xds:///${target} helloworld.Greeter/SayHello
%{ endfor ~}
%{ for target in TARGETS_ENVOY ~}
echo ""
curl --connect-timeout 1 ${target}
%{ endfor ~}
echo ""
EOF
chmod a+x /usr/local/bin/playz
