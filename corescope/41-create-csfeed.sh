
sudo useradd --system --no-create-home --shell /sbin/nologin csfeed
sudo usermod -aG csfeed meshcore
sudo install -d -m 750 -o root -g csfeed /etc/corescope-feed
sudo install -m 640 -o root -g csfeed /etc/mosquitto/certs/cacert.pem \
  /etc/mosquitto/certs/monitor.pem /etc/mosquitto/certs/monitor.key /etc/corescope-feed/
