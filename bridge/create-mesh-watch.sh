#!/bin/bash
#
# create-mesh-watch.sh
#
# create the mesh-watch.py script and setup data
# directories and permissions
#

#sudo tee /usr/local/bin/mesh-watch.py >/dev/null <<'EOF'

tee ~/bin/mesh-decode.py >/dev/null <<'EOF'
#!/usr/bin/env python3
#
# mesh-decode.py
#
# Label and decode MeshCore packets seen on the bridge topic.
#
# Reads lines from:  mosquitto_sub ... -F '%I %l %X'
# Shows route, type, hop path, sender/receiver names (learned from adverts),
# and the text of channel messages whose key is configured.
# 
# Formats follow MeshCore firmware v1.18.0 (src/Packet.cpp, src/Mesh.cpp,
# src/Utils.cpp, src/helpers/AdvertDataHelpers.*, docs/payloads.md).
#

import argparse
import base64
import datetime
import hashlib
import hmac
import json
import os
import struct
import sys

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

ROUTE = {0: "T-FLOOD", 1: "FLOOD", 2: "DIRECT", 3: "T-DIRECT"}
PTYPE = {0: "REQ", 1: "RESPONSE", 2: "DM", 3: "ACK", 4: "ADVERT", 5: "CHAN",
         6: "CHAN-DATA", 7: "ANON_REQ", 8: "PATH", 9: "TRACE", 10: "MULTIPART",
         11: "CONTROL", 15: "RAW_CUSTOM"}
NODE_KIND = {0: "?", 1: "chat", 2: "repeater", 3: "room", 4: "sensor"}
PUBLIC_KEY_HEX = "8b3387e9c5cdea6ac9e5edbaa115cd72"   # MeshCore default "Public" channel


# ---------- channels ----------
class Channel:
    def __init__(self, name, secret):
        self.name = name
        self.secret = secret.ljust(32, b"\0")          # firmware buffer is 32 bytes, zero padded
        self.hash = hashlib.sha256(secret).digest()[0]  # sha256 over the 16 or 32 real key bytes


def parse_key(text):
    text = text.strip()
    try:
        raw = bytes.fromhex(text)
    except ValueError:
        raw = base64.b64decode(text)
    if len(raw) not in (16, 32):
        raise ValueError("channel key must be 16 or 32 bytes")
    return raw


def load_channels(path):
    """Channel file, one per line ('#' starts a comment line):
         hashtag  test                      -> the #test channel (key = sha256("#test")[:16])
         private  Family  <hex or base64>   -> a private channel with its shared secret
    The default Public channel is always included."""
    chans = [Channel("Public", bytes.fromhex(PUBLIC_KEY_HEX))]
    if path and os.path.exists(path):
        with open(path) as f:
            for n, line in enumerate(f, 1):
                parts = line.split()
                if not parts or parts[0].startswith("#"):
                    continue
                try:
                    if parts[0] == "hashtag" and len(parts) == 2:
                        tag = "#" + parts[1].lstrip("#")
                        chans.append(Channel(tag, hashlib.sha256(tag.encode()).digest()[:16]))
                    elif parts[0] == "private" and len(parts) == 3:
                        chans.append(Channel(parts[1], parse_key(parts[2])))
                    else:
                        raise ValueError("expected 'hashtag NAME' or 'private NAME KEY'")
                except Exception as e:
                    print(f"[mesh-watch] {path}:{n}: skipped ({e})", file=sys.stderr)
    return chans


def decrypt(secret, mac_and_data):
    """Utils::MACThenDecrypt: 2-byte HMAC-SHA256 (32-byte key) then AES-128-ECB."""
    if len(mac_and_data) <= 2:
        return None
    mac, data = mac_and_data[:2], mac_and_data[2:]
    if len(data) % 16:
        return None
    if hmac.new(secret, data, hashlib.sha256).digest()[:2] != mac:
        return None
    dec = Cipher(algorithms.AES(secret[:16]), modes.ECB()).decryptor()
    return dec.update(data) + dec.finalize()


# ---------- node names learned from adverts ----------
class Names:
    def __init__(self, path):
        self.path = path
        self.nodes = {}     # pubkey hex -> {"name", "kind", "seen"}
        if path and os.path.exists(path):
            try:
                with open(path) as f:
                    self.nodes = json.load(f)
            except Exception:
                self.nodes = {}

    def learn(self, pub, name, kind):
        rec = self.nodes.get(pub)
        if rec and rec["name"] == name and rec["kind"] == kind:
            return
        self.nodes[pub] = {"name": name, "kind": kind,
                           "seen": datetime.datetime.now().isoformat(timespec="seconds")}
        if self.path:
            tmp = self.path + ".tmp"
            with open(tmp, "w") as f:
                json.dump(self.nodes, f, indent=1)
            os.replace(tmp, self.path)

    def by_prefix(self, prefix_hex):
        """Names whose public key starts with these bytes. Short hashes can match several."""
        hits = [v["name"] for k, v in self.nodes.items() if k.startswith(prefix_hex)]
        if not hits:
            return f"?{prefix_hex[:8]}"
        if len(hits) == 1:
            return hits[0]
        return f"{prefix_hex}:{'|'.join(sorted(hits))}"


# ---------- packet decoding ----------
def clean(b):
    return b.split(b"\0", 1)[0].decode("utf-8", "replace")


def decode(raw, names, chans):
    hdr = raw[0]
    route, ptype = hdr & 3, (hdr >> 2) & 0x0F
    i = 1
    if route in (0, 3):
        i += 4                                    # transport codes
    plen = raw[i]; i += 1
    hops, hsize = plen & 0x3F, (plen >> 6) + 1
    path = [raw[i + k * hsize: i + (k + 1) * hsize].hex() for k in range(hops)]
    i += hops * hsize
    pl = raw[i:]
    rname = ROUTE[route]
    tname = PTYPE.get(ptype, f"type{ptype}")
    via = " > ".join(names.by_prefix(h) for h in path) if path else "-"
    detail = ""

    if ptype == 4 and len(pl) >= 101:            # ADVERT
        pub = pl[:32].hex()
        ts = struct.unpack("<I", pl[32:36])[0]
        app = pl[100:]
        flags = app[0] if app else 0
        j = 1
        lat = lon = None
        if flags & 0x10 and len(app) >= j + 8:
            lat, lon = struct.unpack("<ii", app[j:j + 8]); j += 8
        if flags & 0x20: j += 2
        if flags & 0x40: j += 2
        name = clean(app[j:]) if flags & 0x80 else ""
        kind = NODE_KIND.get(flags & 0x0F, str(flags & 0x0F))
        if name:
            names.learn(pub, name, kind)
        loc = f" @ {lat/1e6:.5f},{lon/1e6:.5f}" if lat is not None else ""
        detail = f'{kind} "{name}" key {pub[:8]}{loc} (unverified)'

    elif ptype in (5, 6) and len(pl) > 3:        # CHAN / CHAN-DATA
        ch_hash = pl[0]
        text = None
        for ch in chans:
            if ch.hash != ch_hash:
                continue
            plain = decrypt(ch.secret, pl[1:])
            if plain is None:
                continue
            if ptype == 5 and len(plain) >= 5:
                sent = datetime.datetime.fromtimestamp(struct.unpack("<I", plain[:4])[0])
                text = f'[{ch.name}] {clean(plain[5:])}   (sent {sent:%H:%M:%S})'
            else:
                text = f"[{ch.name}] data {plain.hex()}"
            break
        detail = text or f"channel {ch_hash:02x} (key not configured)"

    elif ptype in (0, 1, 2, 8) and len(pl) >= 4:  # REQ / RESPONSE / DM / PATH: dest, src hashes
        detail = f"{names.by_prefix(pl[1:2].hex())} -> {names.by_prefix(pl[0:1].hex())} (encrypted)"

    elif ptype == 7 and len(pl) >= 33:           # ANON_REQ: dest hash + full sender key
        detail = f"{names.by_prefix(pl[1:33].hex())} -> {names.by_prefix(pl[0:1].hex())} (login/anon request)"

    elif ptype == 3 and len(pl) >= 4:
        detail = f"ack {pl[:4].hex()}"

    return f"{rname:<8} {tname:<9} via {via:<20} {detail}"


def main():
    ap = argparse.ArgumentParser(description="Label and decode MeshCore packets seen on the bridge topic.")
    ap.add_argument("--channels", default="/etc/mesh-watch/channels",
                    help="channel list (default %(default)s)")
    ap.add_argument("--names", default=os.path.expanduser("~/.cache/mesh-watch-names.json"),
                    help="where learned node names are kept (default %(default)s)")
    ap.add_argument("--raw", action="store_true", help="also print the packet hex")
    args = ap.parse_args()
    os.makedirs(os.path.dirname(args.names), exist_ok=True)
    names = Names(args.names)
    chans = load_channels(args.channels)
    print(f"[mesh-watch] {len(chans)} channel key(s), {len(names.nodes)} known node(s)",
          file=sys.stderr, flush=True)

    for line in sys.stdin:
        p = line.split()
        if len(p) < 3:
            continue
        ts, length, hexdata = p[0], p[1], p[2]
        try:
            raw = bytes.fromhex(hexdata)
            out = decode(raw, names, chans)
        except Exception as e:
            out = f"undecodable ({e.__class__.__name__})"
        print(f"{ts[11:19]} {length:>4}B  {out}", flush=True)
        if args.raw:
            print(f"           {hexdata}", flush=True)


if __name__ == "__main__":
    main()
EOF

#
chmod 750 ~/bin/mesh-decode.py

sudo mkdir -p /etc/mesh-watch
sudo tee /etc/mesh-watch/channels >/dev/null <<'EOF'
# hashtag NAME           -> e.g. the #test channel
# private NAME KEY       -> KEY as 32 hex characters or base64, from the app's channel share
hashtag test
EOF

sudo chown -R root:meshcore /etc/mesh-watch
sudo chmod 750 /etc/mesh-watch
sudo chmod 640 /etc/mesh-watch/channels

