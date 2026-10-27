#!/bin/bash
#
# mesh-watch.sh
#
# Connect to mosquitto bridge and display packets seen
#
# Requires:
#  MC_FQDN env var to be set
#  mesh-decode.py for processing
#  read access to /etc/mosquitto/certs/monitor.key
#  read access to /etc/mesh-watch/channels

if [ ! -x ~/bin/mesh-decode.py ]; then
  echo "~/bin/mesh-decode.py not executable or missing"
  exit 1
elif [ "x$MC_FQDN" = "x" ]; then
  echo "MC_FQDN not set"
  exit 2
elif [ ! -r /etc/mosquitto/certs/monitor.key ]; then
  echo "/etc/mosquitto/certs/monitor.key not readable"
  exit 3
elif [ ! -r /etc/mesh-watch/channels ]; then
  echo "/etc/mesh-watch/channels not readable"
  exit 4
fi

mosquitto_sub -h "$MC_FQDN" -p 8883 \
  --cafile /etc/mosquitto/certs/cacert.pem \
  --cert /etc/mosquitto/certs/monitor.pem \
  --key /etc/mosquitto/certs/monitor.key \
  -t meshcore/bridge -F '%I %l %X' | \
  ~/bin/mesh-decode.py
