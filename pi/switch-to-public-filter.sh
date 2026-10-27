sudo tee /opt/meshcore-bridge/meshcore-bridge-filtered >/dev/null <<'EOF'
#!/opt/meshcore-bridge/venv/bin/python
"""Run meshcore-net-bridge with a channel filter, in both directions.

Drops MeshCore group packets (channel text and channel data) that belong to a
blocked channel, both radio -> MQTT and MQTT -> radio. The upstream app is
unchanged; this wrapper patches its two packet entry points before starting it.

Block list file (default /etc/meshcore-bridge/block-channels), one per line,
'#' starts a comment line:
    public            the default MeshCore Public channel
    hashtag NAME      a hashtag channel, e.g.  hashtag test
A packet is dropped only when its channel hash matches AND its 2-byte MAC
verifies with that channel's key, so other channels sharing the 1-byte hash
still pass.
"""
import hashlib
import hmac
import logging
import os
import sys

from meshcore_bridge import main as bridge_main
from meshcore_bridge.mqtt_handler import MqttHandler
from meshcore_bridge.serial_handler import SerialHandler

PUBLIC_KEY = bytes.fromhex("8b3387e9c5cdea6ac9e5edbaa115cd72")
BLOCK_FILE = os.environ.get("MESHCORE_BLOCK_FILE", "/etc/meshcore-bridge/block-channels")
log = logging.getLogger("meshcore_bridge.filter")


def load_blocked(path):
    keys = []
    if not os.path.exists(path):
        keys.append(("Public", PUBLIC_KEY))          # no file: block Public only
        return keys
    with open(path) as f:
        for n, line in enumerate(f, 1):
            parts = line.split()
            if not parts or parts[0].startswith("#"):
                continue
            if parts[0] == "public" and len(parts) == 1:
                keys.append(("Public", PUBLIC_KEY))
            elif parts[0] == "hashtag" and len(parts) == 2:
                tag = "#" + parts[1].lstrip("#")
                keys.append((tag, hashlib.sha256(tag.encode()).digest()[:16]))
            else:
                sys.exit(f"{path}:{n}: expected 'public' or 'hashtag NAME'")
    return keys


BLOCKED = [(name, key, hashlib.sha256(key).digest()[0], key.ljust(32, b"\0"))
           for name, key in load_blocked(BLOCK_FILE)]


def blocked_channel(pkt):
    """Return the blocked channel's name if pkt is a group packet on it, else None."""
    try:
        hdr = pkt[0]
        route, ptype = hdr & 0x03, (hdr >> 2) & 0x0F
        if ptype not in (5, 6):                       # GRP_TXT, GRP_DATA
            return None
        i = 1 + (4 if route in (0, 3) else 0)         # transport codes
        plen = pkt[i]; i += 1
        i += (plen & 0x3F) * ((plen >> 6) + 1)        # path bytes
        pl = pkt[i:]
        if len(pl) < 4:
            return None
        for name, _key, ch_hash, secret in BLOCKED:
            if pl[0] == ch_hash and \
               hmac.new(secret, pl[3:], hashlib.sha256).digest()[:2] == pl[1:3]:
                return name
    except IndexError:
        return None
    return None


_publish = MqttHandler.publish_packet
_write = SerialHandler.write_packet


def publish_filtered(self, payload):                  # radio -> MQTT
    ch = blocked_channel(payload)
    if ch:
        log.info("Blocked %s packet radio->MQTT (%d bytes)", ch, len(payload))
        return
    _publish(self, payload)


def write_filtered(self, payload):                    # MQTT -> radio
    ch = blocked_channel(payload)
    if ch:
        log.info("Blocked %s packet MQTT->radio (%d bytes)", ch, len(payload))
        return
    _write(self, payload)


MqttHandler.publish_packet = publish_filtered
SerialHandler.write_packet = write_filtered

if __name__ == "__main__":
    print(f"[filter] blocking: {', '.join(b[0] for b in BLOCKED) or 'nothing'}", file=sys.stderr, flush=True)
    bridge_main.main()
EOF
sudo chmod 755 /opt/meshcore-bridge/meshcore-bridge-filtered

# what to block (without this file, Public alone is blocked)
sudo tee /etc/meshcore-bridge/block-channels >/dev/null <<'EOF'
public
# hashtag test
EOF
sudo chown root:meshbridge /etc/meshcore-bridge/block-channels
sudo chmod 640 /etc/meshcore-bridge/block-channels

# switch the service to the wrapper
sudo sed -i 's#^ExecStart=.*#ExecStart=/opt/meshcore-bridge/meshcore-bridge-filtered -c /etc/meshcore-bridge/config.yaml#' \
  /etc/systemd/system/meshcore-bridge.service
sudo systemctl daemon-reload && sudo systemctl restart meshcore-bridge
journalctl -u meshcore-bridge -n 10 --no-pager    # expect: [filter] blocking: Public

