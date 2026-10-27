sudo tee /etc/systemd/system/corescope-feed@.service >/dev/null <<'EOF'
[Unit]
Description=CoreScope feed: %i
Wants=network-online.target mosquitto-corescope.service
After=network-online.target mosquitto.service mosquitto-corescope.service
PartOf=mosquitto-corescope.service

[Service]
User=csfeed
Group=csfeed
EnvironmentFile=/etc/corescope-feed/common.env
EnvironmentFile=/etc/corescope-feed/%i.env
ExecStart=/usr/local/bin/corescope-feed.sh
Restart=always
RestartSec=10
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now corescope-feed@tx1 corescope-feed@co1 corescope-feed@mt1
systemctl status 'corescope-feed@*' --no-pager | grep -E '●|Active:'
