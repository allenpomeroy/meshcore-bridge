sudo apt update
sudo apt install -y stunnel4 python3-venv git mosquitto-clients
sudo useradd --system --no-create-home --shell /usr/sbin/nologin -G dialout meshbridge
sudo install -d -m 750 -o root -g meshbridge /etc/meshcore-bridge /etc/meshcore-bridge/tls
sudo cp certs/cacert.pem certs/client.pem certs/client.key /etc/meshcore-bridge/tls/
sudo chown root:meshbridge /etc/meshcore-bridge/tls/*
sudo chmod 640 /etc/meshcore-bridge/tls/*
