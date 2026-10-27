
sudo useradd --system --create-home --shell /sbin/nologin tunnel
sudo install -d -m 700 -o tunnel -g tunnel /home/tunnel/.ssh
sudo install -m 600 -o tunnel -g tunnel /dev/null /home/tunnel/.ssh/authorized_keys

sudo tee -a /etc/ssh/sshd_config >/dev/null <<'EOF'

Match User tunnel
    AllowTcpForwarding remote
    X11Forwarding no
    AllowAgentForwarding no
    PermitTTY no
    PasswordAuthentication no
    ClientAliveInterval 30
    ClientAliveCountMax 3
EOF
sudo sshd -t && sudo systemctl reload sshd
sudo sshd -T -C user=tunnel,host=x,addr=127.0.0.1 | grep -Ei 'allowtcpforwarding|clientalive'

sleep 3
echo "all three pi ssh ports should be free, 22001, 22002, 22003"
sudo ss -ltn | grep -E ':2200[1-3] '

echo 
echo "Record this VPS host-key fingerprint for setup on the raspberry pi systems:"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub

