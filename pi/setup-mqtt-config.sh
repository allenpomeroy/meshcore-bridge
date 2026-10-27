

sudo tee /etc/meshcore-bridge/stunnel.conf >/dev/null <<'EOF'
foreground = yes
pid =
debug = notice

[mqtt]
client = yes
accept = 127.0.0.1:1883
connect = meshcore-relay.pomeroy.us:8883
cert = /etc/meshcore-bridge/tls/client.pem
key = /etc/meshcore-bridge/tls/client.key
CAfile = /etc/meshcore-bridge/tls/cacert.pem
verifyChain = yes
checkHost = meshcore-relay.pomeroy.us
sslVersionMin = TLSv1.2
EOF

STUNNEL=$(command -v stunnel4 || command -v stunnel); echo "$STUNNEL"
sudo tee /etc/systemd/system/mqtt-stunnel.service >/dev/null <<EOF
[Unit]
Description=stunnel: local MQTT to VPS broker over mutual TLS
After=network-online.target
Wants=network-online.target

[Service]
User=meshbridge
ExecStart=$STUNNEL /etc/meshcore-bridge/stunnel.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now mqtt-stunnel
journalctl -u mqtt-stunnel -n 20 --no-pager



