cd /opt/meshcore-bridge/src
sudo sed -i 's|^\(        \)self._client.publish(self._topic, payload)$|&\n\1self._client.publish(f"meshcore/observed/{self._node_id}", payload)|' meshcore_bridge/mqtt_handler.py
sudo git diff --stat                # 1 file changed, 1 insertion(+)
sudo git diff | grep '^+ '          # +        self._client.publish(f"meshcore/observed/{self._node_id}", payload)
sudo /opt/meshcore-bridge/venv/bin/pip install --no-deps --force-reinstall /opt/meshcore-bridge/src
sudo systemctl restart meshcore-bridge
journalctl -u meshcore-bridge -n 10 --no-pager    # Connected / Subscribed / Bridge running
