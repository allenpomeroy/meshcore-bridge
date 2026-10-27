journalctl -u corescope-ingestor -n 40 --no-pager | grep -E 'MQTT \[intake\]|error'
journalctl -u corescope-server -n 40 --no-pager | tail -5
curl -s http://127.0.0.1:3000/api/stats; echo
systemctl show corescope-server -p IPAddressDeny -p IPAddressAllow
#sudo firewall-cmd --list-all | grep -E 'services|ports'     # no 3000, no 1884
