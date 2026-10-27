#!/bin/bash
#
# fleet-status.sh
#

for h in meshcore-tx1 meshcore-co1 meshcore-mt1; do
  echo "== $h"; ssh -o ConnectTimeout=10 "$h" \
    'systemctl is-active mgmt-tunnel mqtt-stunnel meshcore-bridge; journalctl -u meshcore-bridge -n 3 --no-pager -o cat'
done
