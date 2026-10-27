# allowlist mode checks advert signatures, which needs this library in the bridge venv
sudo /opt/meshcore-bridge/venv/bin/pip install cryptography

sudo tee /opt/meshcore-bridge/meshcore-bridge-filtered >/dev/null <<'EOF'
#!/opt/meshcore-bridge/venv/bin/python
"""Run meshcore-net-bridge with a packet filter applied in both directions
(radio -> MQTT and MQTT -> radio). The upstream app is unchanged; this wrapper
patches its two packet entry points before starting it.

ALLOWLIST MODE - used when /etc/meshcore-bridge/allowlist exists.
Only these packets cross; everything else is dropped:
  ADVERT            from a listed node, with a valid Ed25519 signature
  DM, REQ, RESPONSE, PATH
                    sender AND recipient both listed (matched on the 1-byte
                    key hash these packets carry)
  ANON_REQ          (logins) full sender key listed AND recipient listed
  CHAN, CHAN-DATA   on a listed channel (channel hash AND 2-byte MAC must match)
  ACK, multipart ACK
                    always: they carry no sender or recipient, and without
                    them listed nodes never see their DMs confirmed
  anything else (TRACE, CONTROL, RAW_CUSTOM, other channels, unlisted nodes)
                    dropped
Allowlist lines ('#' starts a comment line):
  node    <64 hex chars public key>  [label]
  private <name> <channel secret: 32 hex chars or base64>
  hashtag <name>
  public                      (allow the Public channel too)

BLOCKLIST MODE - used when there is no allowlist. Lines in
/etc/meshcore-bridge/block-channels ('public', 'hashtag NAME') are dropped;
everything else crosses. With neither file present, Public alone is blocked.
"""
import base64
import hashlib
import hmac
import logging
import os
import sys
import threading

from meshcore_bridge import main as bridge_main
from meshcore_bridge.mqtt_handler import MqttHandler
from meshcore_bridge.serial_handler import SerialHandler

PUBLIC_KEY = bytes.fromhex("8b3387e9c5cdea6ac9e5edbaa115cd72")
ALLOW_FILE = os.environ.get("MESHCORE_ALLOW_FILE", "/etc/meshcore-bridge/allowlist")
BLOCK_FILE = os.environ.get("MESHCORE_BLOCK_FILE", "/etc/meshcore-bridge/block-channels")
STATS_EVERY = 900   # seconds between drop-count summaries in the log

log = logging.getLogger("meshcore_bridge.filter")
TYPE_NAME = {0: "REQ", 1: "RESPONSE", 2: "DM", 3: "ACK", 4: "ADVERT", 5: "CHAN",
             6: "CHAN-DATA", 7: "ANON_REQ", 8: "PATH", 9: "TRACE", 10: "MULTIPART",
             11: "CONTROL", 15: "RAW_CUSTOM"}


def channel(name, key):
    return (name, hashlib.sha256(key).digest()[0], key.ljust(32, b"\0"))


def hashtag(name):
    tag = "#" + name.lstrip("#")
    return channel(tag, hashlib.sha256(tag.encode()).digest()[:16])


def parse_secret(text):
    try:
        raw = bytes.fromhex(text)
    except ValueError:
        raw = base64.b64decode(text, validate=True)
    if len(raw) not in (16, 32):
        raise ValueError("channel secret must be 16 or 32 bytes")
    return raw


def read_lines(path):
    with open(path) as f:
        for n, line in enumerate(f, 1):
            parts = line.split()
            if parts and not parts[0].startswith("#"):
                yield n, parts


# ---------- configuration ----------
MODE = "allowlist" if os.path.exists(ALLOW_FILE) else "blocklist"
NODES = {}        # pubkey bytes -> label
CHANNELS = []     # (name, hash byte, 32-byte secret)

if MODE == "allowlist":
    for n, p in read_lines(ALLOW_FILE):
        try:
            if p[0] == "node" and len(p) >= 2:
                key = bytes.fromhex(p[1])
                if len(key) != 32:
                    raise ValueError("node key must be 64 hex characters")
                NODES[key] = " ".join(p[2:]) or p[1][:8]
            elif p[0] == "private" and len(p) == 3:
                CHANNELS.append(channel(p[1], parse_secret(p[2])))
            elif p[0] == "hashtag" and len(p) == 2:
                CHANNELS.append(hashtag(p[1]))
            elif p[0] == "public" and len(p) == 1:
                CHANNELS.append(channel("Public", PUBLIC_KEY))
            else:
                raise ValueError("expected node/private/hashtag/public")
        except ValueError as e:
            sys.exit(f"{ALLOW_FILE}:{n}: {e}")
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
    from cryptography.exceptions import InvalidSignature
else:
    if os.path.exists(BLOCK_FILE):
        for n, p in read_lines(BLOCK_FILE):
            if p[0] == "public" and len(p) == 1:
                CHANNELS.append(channel("Public", PUBLIC_KEY))
            elif p[0] == "hashtag" and len(p) == 2:
                CHANNELS.append(hashtag(p[1]))
            else:
                sys.exit(f"{BLOCK_FILE}:{n}: expected 'public' or 'hashtag NAME'")
    else:
        CHANNELS.append(channel("Public", PUBLIC_KEY))

NODE_HASHES = {k[0] for k in NODES}


# ---------- packet inspection ----------
def split(pkt):
    """Return (payload type, payload bytes) per MeshCore src/Packet.cpp."""
    hdr = pkt[0]
    route, ptype = hdr & 0x03, (hdr >> 2) & 0x0F
    i = 1 + (4 if route in (0, 3) else 0)          # transport codes
    plen = pkt[i]; i += 1
    i += (plen & 0x3F) * ((plen >> 6) + 1)          # path bytes
    return ptype, pkt[i:]


def on_channel(pl):
    """Name of the configured channel this group payload belongs to, else None."""
    if len(pl) < 4:
        return None
    for name, ch_hash, secret in CHANNELS:
        if pl[0] == ch_hash and hmac.new(secret, pl[3:], hashlib.sha256).digest()[:2] == pl[1:3]:
            return name
    return None


def advert_ok(pl):
    if len(pl) < 101:
        return False
    pub, ts, sig, app = pl[:32], pl[32:36], pl[36:100], pl[100:]
    if pub not in NODES:
        return False
    try:
        Ed25519PublicKey.from_public_bytes(pub).verify(sig, pub + ts + app)
        return True
    except (InvalidSignature, ValueError):
        return False


def verdict(pkt):
    """True to forward, False to drop."""
    try:
        ptype, pl = split(pkt)
    except IndexError:
        return False
    if MODE == "blocklist":
        return not (ptype in (5, 6) and on_channel(pl))
    if ptype == 4:                                   # ADVERT
        return advert_ok(pl)
    if ptype in (0, 1, 2, 8):                        # REQ RESPONSE DM PATH: dest, src hash
        return len(pl) >= 4 and pl[0] in NODE_HASHES and pl[1] in NODE_HASHES
    if ptype == 7:                                   # ANON_REQ: dest hash, sender key
        return len(pl) >= 33 and pl[0] in NODE_HASHES and pl[1:33] in NODES
    if ptype in (5, 6):                              # channel text / data
        return on_channel(pl) is not None
    if ptype == 3:                                   # ACK
        return True
    if ptype == 10:                                  # MULTIPART: only multipart ACKs exist
        return len(pl) >= 5 and (pl[0] & 0x0F) == 3
    return False


# ---------- hook into the bridge ----------
dropped = {}
lock = threading.Lock()


def count_drop(pkt, direction):
    t = TYPE_NAME.get((pkt[0] >> 2) & 0x0F, "?") if pkt else "?"
    with lock:
        dropped[(direction, t)] = dropped.get((direction, t), 0) + 1
    log.debug("Dropped %s %s (%d bytes)", t, direction, len(pkt))


def report():
    with lock:
        if dropped:
            log.info("Dropped in last %d s: %s", STATS_EVERY,
                     ", ".join(f"{t} {d} x{c}" for (d, t), c in sorted(dropped.items())))
            dropped.clear()
    timer = threading.Timer(STATS_EVERY, report)
    timer.daemon = True
    timer.start()


_publish = MqttHandler.publish_packet
_write = SerialHandler.write_packet


def publish_filtered(self, payload):                 # radio -> MQTT
    if verdict(payload):
        _publish(self, payload)
    else:
        count_drop(payload, "radio->MQTT")


def write_filtered(self, payload):                   # MQTT -> radio
    if verdict(payload):
        _write(self, payload)
    else:
        count_drop(payload, "MQTT->radio")


MqttHandler.publish_packet = publish_filtered
SerialHandler.write_packet = write_filtered

if __name__ == "__main__":
    if MODE == "allowlist":
        print(f"[filter] allowlist: {len(NODES)} node(s) "
              f"({', '.join(sorted(NODES.values()))}), channels: "
              f"{', '.join(c[0] for c in CHANNELS) or 'none'}", file=sys.stderr, flush=True)
    else:
        print(f"[filter] blocklist: {', '.join(c[0] for c in CHANNELS) or 'nothing'}",
              file=sys.stderr, flush=True)
    report()
    bridge_main.main()
EOF
sudo chmod 755 /opt/meshcore-bridge/meshcore-bridge-filtered

# blocklist mode: what to block (without this file, Public alone is blocked)
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
journalctl -u meshcore-bridge -n 10 --no-pager    # expect: [filter] blocklist: Public
