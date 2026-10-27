sudo tee /usr/local/bin/corescope-feed.sh >/dev/null <<'EOF'
#!/bin/bash
# Relay raw MeshCore packets from the hub broker (mutual TLS) into
# CoreScope's intake broker as {"raw":"<hex>","origin":"<name>"} JSON.
# All settings come from the environment (see /etc/corescope-feed/*.env).
set -euo pipefail
: "${VPS_FQDN:?}" "${CERT_DIR:?}" "${SRC_TOPIC:?}" "${REGION:?}" "${OBSERVER:?}" "${OBSERVER_NAME:?}"
mosquitto_sub -h "$VPS_FQDN" -p "${HUB_PORT:-8883}" \
    --cafile "$CERT_DIR/cacert.pem" --cert "$CERT_DIR/monitor.pem" --key "$CERT_DIR/monitor.key" \
    -i "csfeed-sub-$OBSERVER" -t "$SRC_TOPIC" \
    -F "{\"raw\":\"%x\",\"origin\":\"$OBSERVER_NAME\"}" \
  | mosquitto_pub -h 127.0.0.1 -p "${CORESCOPE_MQTT_PORT:-1884}" \
    -i "csfeed-pub-$OBSERVER" -t "meshcore/$REGION/$OBSERVER/packets" -l
EOF
sudo chmod 755 /usr/local/bin/corescope-feed.sh
sudo restorecon -v /usr/local/bin/corescope-feed.sh
bash -n /usr/local/bin/corescope-feed.sh && echo syntax-ok


# create coroscope settings

sudo tee /etc/corescope-feed/common.env >/dev/null <<'EOF'
VPS_FQDN=$MC_FQDN
CERT_DIR=/etc/corescope-feed
EOF
for s in tx1 co1 mt1; do
  R=$(echo "$s" | tr a-z A-Z)
  printf 'SRC_TOPIC=meshcore/observed/%s\nREGION=%s\nOBSERVER=%s\nOBSERVER_NAME=meshcore-%s\n' "$s" "$R" "$s" "$s" \
    | sudo tee /etc/corescope-feed/$s.env
done
sudo chown root:csfeed /etc/corescope-feed/*.env && sudo chmod 640 /etc/corescope-feed/*.env
