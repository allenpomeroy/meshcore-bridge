#!/bin/bash
#
# setup-mosquitto.sh
#
# assumes dnf install mosquitto has been run successfully
#
echo "mosquitto version must be 2.0.x"
mosquitto -h | head -1          # expect: mosquitto version 2.0.x

# certificates and permissions
echo "installing mosquitto certificates and permissions"
sudo mkdir -p /etc/mosquitto/certs
sudo chown -R root:mosquitto /etc/mosquitto

#sudo cp certs/* keys/* /etc/mosquitto/certs/
certificates="cacert.pem server.pem server.key monitor.pem monitor.key"
for c in $certificates
do
  sudo cp ../certs/$c  /etc/mosquitto/certs/
done
sudo chown root:mosquitto /etc/mosquitto/certs/*
sudo chmod 640 /etc/mosquitto/certs/*
#sudo restorecon -Rv /etc/mosquitto

# configuration
echo "mosquitto configuration"
sudo cp /etc/mosquitto/mosquitto.conf /etc/mosquitto/mosquitto.conf.orig
sudo tee /etc/mosquitto/mosquitto.conf >/dev/null <<'EOF'
persistence false
log_dest stderr
log_type error
log_type warning
log_type notice
log_type information
connection_messages true

allow_anonymous false
acl_file /etc/mosquitto/aclfile

listener 8883
cafile   /etc/mosquitto/certs/cacert.pem
certfile /etc/mosquitto/certs/server.pem
keyfile  /etc/mosquitto/certs/server.key
require_certificate true
use_identity_as_username true
tls_version tlsv1.2
EOF

# ACL

sudo tee /etc/mosquitto/aclfile >/dev/null <<'EOF'
user meshcore-tx1
topic readwrite meshcore/bridge
topic readwrite meshcore/test

user meshcore-co1
topic readwrite meshcore/bridge
topic readwrite meshcore/test

user meshcore-mt1
topic readwrite meshcore/bridge
topic readwrite meshcore/test

user mqtt-monitor
topic read meshcore/#
topic read $SYS/#
EOF
sudo chown root:mosquitto /etc/mosquitto/aclfile && sudo chmod 640 /etc/mosquitto/aclfile
sudo chown -R root:mosquitto /etc/mosquitto
sudo chmod  750 /etc/mosquitto
