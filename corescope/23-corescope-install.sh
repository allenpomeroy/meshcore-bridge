
cd build/CoreScope || exit 1

sudo useradd --system --no-create-home --home-dir /var/lib/corescope --shell /sbin/nologin corescope
sudo install -d -m 755 /opt/corescope /opt/corescope/bin
sudo install -m 755 dist/corescope-server dist/corescope-ingestor /opt/corescope/bin/
sudo rm -rf /opt/corescope/public && sudo cp -r public /opt/corescope/public
sudo chmod -R a+rX /opt/corescope/public
sudo install -d -m 750 -o root -g corescope /etc/corescope
sudo install -m 640 -o root -g corescope channel-rainbow.json /etc/corescope/
echo "v3.14.0 $(git rev-parse HEAD)" | sudo tee /opt/corescope/VERSION

sudo usermod -aG corescope meshcore

sudo restorecon -Rv /opt/corescope /etc/corescope
