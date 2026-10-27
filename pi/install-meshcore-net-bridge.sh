

sudo git clone https://github.com/kabili207/meshcore-net-bridge.git /opt/meshcore-bridge/src
sudo git -C /opt/meshcore-bridge/src checkout 61335a22a6d0829fcfb990e1cb026f72f3013922
sudo python3 -m venv /opt/meshcore-bridge/venv
sudo /opt/meshcore-bridge/venv/bin/pip install /opt/meshcore-bridge/src
/opt/meshcore-bridge/venv/bin/meshcore-bridge --help
