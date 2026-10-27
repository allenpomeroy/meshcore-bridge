run-on-all sudo nmcli connection modify Meshcore-WiFi \
  ipv4.method auto ipv4.route-metric 600 ipv4.dns-priority 100 \
  ipv6.method disabled \
  connection.autoconnect yes connection.autoconnect-priority 10
