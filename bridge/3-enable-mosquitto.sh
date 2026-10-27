
# assumes iptables firewall has been setup allow 8883/tcp inbound

#sudo firewall-cmd --permanent --add-port=8883/tcp && sudo firewall-cmd --reload

sudo systemctl enable --now mosquitto
sudo systemctl status mosquitto --no-pager
sudo ss -ltnp | grep 8883
