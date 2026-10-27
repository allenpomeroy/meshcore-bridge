
echo "configure meshcore-net-bridge"
echo 

sudo tee /etc/meshcore-bridge/config.yaml >/dev/null <<'EOF'
mqtt:
  broker: "127.0.0.1"
  port: 1883
  topic: "meshcore/bridge"
node:
  id: "mt1"
serial:
  port: "/dev/ttyAMA0"
  baud: 115200
EOF
sudo chown root:meshbridge /etc/meshcore-bridge/config.yaml && sudo chmod 640 /etc/meshcore-bridge/config.yaml


echo "setup meshcore-bridge service"
echo 

sudo tee /etc/systemd/system/meshcore-bridge.service >/dev/null <<'EOF'
[Unit]
Description=MeshCore RS232 bridge <-> MQTT
After=mqtt-stunnel.service
Wants=mqtt-stunnel.service

[Service]
User=meshbridge
ExecStart=/opt/meshcore-bridge/venv/bin/meshcore-bridge -c /etc/meshcore-bridge/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now meshcore-bridge
journalctl -u meshcore-bridge -f

