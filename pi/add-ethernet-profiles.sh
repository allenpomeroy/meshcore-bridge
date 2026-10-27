run-on-all sudo nmcli connection add type ethernet con-name eth-dhcp \
  ipv4.method auto ipv4.route-metric 100 ipv4.dns-priority 50 ipv4.may-fail no \
  ipv6.method disabled \
  connection.autoconnect yes connection.autoconnect-priority 100 \
  connection.autoconnect-retries 0
