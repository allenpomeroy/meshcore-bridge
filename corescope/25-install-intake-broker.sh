command -v mosquitto                      # /usr/sbin/mosquitto
sudo install -d -m 750 -o root -g mosquitto /etc/mosquitto-corescope
sudo tee /etc/mosquitto-corescope/mosquitto.conf >/dev/null <<'EOF'
# Private intake broker for CoreScope: loopback only, no TLS, no auth.
listener 1884 127.0.0.1
allow_anonymous true
persistence false
log_dest stderr
log_type error
log_type warning
log_type notice
connection_messages true
EOF
sudo chown root:mosquitto /etc/mosquitto-corescope/mosquitto.conf
sudo chmod 640 /etc/mosquitto-corescope/mosquitto.conf

sudo tee /etc/systemd/system/mosquitto-corescope.service >/dev/null <<'EOF'
[Unit]
Description=Mosquitto intake broker for CoreScope (127.0.0.1:1884)
After=network.target

[Service]
Type=simple
User=mosquitto
Group=mosquitto
ExecStart=/usr/sbin/mosquitto -c /etc/mosquitto-corescope/mosquitto.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now mosquitto-corescope
