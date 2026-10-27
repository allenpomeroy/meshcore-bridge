sudo systemctl enable systemd-time-wait-sync    # makes time-sync.target wait for NTP
sudo tee /etc/systemd/system/repeater-clock.service >/dev/null <<'EOF'
[Unit]
Description=Set repeater clock from the Pi
After=time-sync.target
Wants=time-sync.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c '/usr/local/bin/mc-repeater-cli /dev/ttyACM0 "time $(date -u +%%s)"'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now repeater-clock
