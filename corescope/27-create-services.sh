sudo tee /etc/systemd/system/corescope-ingestor.service >/dev/null <<'EOF'
[Unit]
Description=CoreScope ingestor (MQTT 127.0.0.1:1884 -> SQLite)
Wants=mosquitto-corescope.service
After=network.target mosquitto-corescope.service

[Service]
User=corescope
Group=corescope
StateDirectory=corescope
StateDirectoryMode=0750
WorkingDirectory=/var/lib/corescope
Environment=CORESCOPE_INGESTOR_STATS=/var/lib/corescope/ingestor-stats.json
ExecStart=/opt/corescope/bin/corescope-ingestor -config /etc/corescope/config.json
Restart=always
RestartSec=5
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
IPAddressDeny=any
IPAddressAllow=localhost

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/corescope-server.service >/dev/null <<'EOF'
[Unit]
Description=CoreScope web server (127.0.0.1:3000 behind nginx)
Wants=corescope-ingestor.service
After=network.target corescope-ingestor.service

[Service]
User=corescope
Group=corescope
StateDirectory=corescope
StateDirectoryMode=0750
WorkingDirectory=/var/lib/corescope
Environment=CORESCOPE_INGESTOR_STATS=/var/lib/corescope/ingestor-stats.json
ExecStart=/opt/corescope/bin/corescope-server -config-dir /etc/corescope -db /var/lib/corescope/meshcore.db -public /opt/corescope/public -port 3000
Restart=always
RestartSec=5
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
IPAddressDeny=any
IPAddressAllow=localhost

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now corescope-ingestor corescope-server
