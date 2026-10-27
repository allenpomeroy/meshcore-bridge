sudo tee /usr/local/bin/mc-repeater-cli >/dev/null <<'EOF'
#!/usr/bin/env python3
"""Usage: mc-repeater-cli /dev/ttyACM0 "get bridge.type" "get radio" ..."""
import sys, time
import serial

if len(sys.argv) < 3:
    sys.exit(__doc__)
port, cmds = sys.argv[1], sys.argv[2:]
with serial.Serial(port, 115200, timeout=0.2) as s:
    time.sleep(0.5)
    s.reset_input_buffer()
    for cmd in cmds:
        s.write((cmd + "\r").encode())
        buf, deadline = b"", time.time() + 3
        while time.time() < deadline:
            chunk = s.read(512)
            if chunk:
                buf += chunk
                deadline = time.time() + 0.6
        print(f"$ {cmd}\n{buf.decode(errors='replace').strip()}\n")
EOF
sudo chmod 755 /usr/local/bin/mc-repeater-cli
sudo usermod -aG dialout "$USER"   # log out and back in once
