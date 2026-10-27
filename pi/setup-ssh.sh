
sudo useradd --system --create-home --home-dir /var/lib/meshtun --shell /usr/sbin/nologin meshtun
sudo -u meshtun install -d -m 700 /var/lib/meshtun/.ssh
sudo -u meshtun ssh-keygen -t ed25519 -N '' -C "meshtun@$(hostname)" -f /var/lib/meshtun/.ssh/id_ed25519
sudo cat /var/lib/meshtun/.ssh/id_ed25519.pub

# pin the vps host key
# test node
#ssh-keyscan -t ed25519 meshcore-relay.pomeroy.us | sudo -u meshtun tee /var/lib/meshtun/.ssh/known_hosts
# production node
ssh-keyscan -p 32800 -t ed25519 mcr.pomeroy.us | sudo -u meshtun tee /var/lib/meshtun/.ssh/known_hosts
sudo -u meshtun ssh-keygen -F '[mcr.pomeroy.us]:32800' -lf /var/lib/meshtun/.ssh/known_hosts
