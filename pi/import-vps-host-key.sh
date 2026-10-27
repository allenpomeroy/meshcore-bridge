ssh-keyscan -t ed25519 meshcore-relay.pomeroy.us | sudo -u meshtun tee /var/lib/meshtun/.ssh/known_hosts
sudo -u meshtun ssh-keygen -lf /var/lib/meshtun/.ssh/known_hosts
