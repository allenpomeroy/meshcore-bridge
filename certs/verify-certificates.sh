#!/bin/bash
#
# verify-certificates.sh 
#
# 1. Subject CN of each Pi cert - this exact string becomes the MQTT username
openssl x509 -in ~/certs/client-tx1.pem -noout -subject -nameopt multiline | grep commonName

# 2. Extended key usage: Pi certs need "TLS Web Client Authentication" (or no EKU at all);
#    the VPS cert needs "TLS Web Server Authentication" (or no EKU)
openssl x509 -in ~/certs/client-tx1.pem -noout -ext extendedKeyUsage

# 3. VPS cert SAN must contain VPS_FQDN (stunnel checks it)
openssl x509 -in ~/certs/server.pem -noout -ext subjectAltName

# 4. Chain verifies against your CA, with the right purpose
openssl verify -CAfile ~/certs/cacert.pem -purpose sslclient ~/certs/client-tx1.pem  # on each Pi
openssl verify -CAfile ~/certs/cacert.pem -purpose sslserver ~/certs/server.pem      # on the VPS

# 5. Key matches cert (the two hashes must be identical)
openssl x509 -in ~/certs/server.pem -noout -pubkey | sha256sum
openssl pkey -in ~/certs/server.key -pubout | sha256sum

