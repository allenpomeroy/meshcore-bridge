
#mosquitto_sub -h VPS_FQDN -p 8883 --cafile /etc/mosquitto/certs/cacert.pem  \

#mosquitto_sub -h meshcore-relay.pomeroy.us -p 8883 --cafile /etc/mosquitto/certs/cacert.pem \

mosquitto_sub -h mcr.pomeroy.us -p 8883 --cafile /etc/mosquitto/certs/cacert.pem \
  --cert /etc/mosquitto/certs/monitor.pem --key /etc/mosquitto/certs/monitor.key \
  -t 'meshcore/#' -v -W 5
