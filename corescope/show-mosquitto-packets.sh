mosquitto_sub -h mcr.pomeroy.us -p 8883 \
 --cafile /etc/mosquitto/certs/cacert.pem \
 --cert /etc/mosquitto/certs/monitor.pem \
 --key /etc/mosquitto/certs/monitor.key \
 -t meshcore/bridge -F '%I %l bytes' -W 120
