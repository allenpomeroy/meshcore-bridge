sudo tee /etc/corescope-feed/common.env >/dev/null <<'EOF'
VPS_FQDN=mcr.pomeroy.us
CERT_DIR=/etc/corescope-feed
EOF
for s in tx1 co1 mt1; do
  R=$(echo "$s" | tr a-z A-Z)
  printf 'SRC_TOPIC=meshcore/observed/%s\nREGION=%s\nOBSERVER=%s\nOBSERVER_NAME=meshcore-%s\n' "$s" "$R" "$s" "$s" \
    | sudo tee /etc/corescope-feed/$s.env
done
# run the glob as root: the folder is 750 root:csfeed, so your own shell cannot list it
sudo sh -c 'chown root:csfeed /etc/corescope-feed/*.env && chmod 640 /etc/corescope-feed/*.env'
sudo ls -l /etc/corescope-feed/          # 4 .env files, root csfeed, -rw-r-----
sudo cat /etc/corescope-feed/common.env  # VPS_FQDN= must show the real name, not a $VARIABLE
