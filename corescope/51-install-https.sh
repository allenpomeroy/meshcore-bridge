
# step 1

sudo dnf install -y nginx httpd-tools certbot
#sudo firewall-cmd --permanent --add-service=http --add-service=https && sudo firewall-cmd --reload



# step 2

sudo install -d -m 755 /var/www/letsencrypt && sudo restorecon -Rv /var/www/letsencrypt
sudo tee /etc/nginx/conf.d/corescope-http.conf >/dev/null <<'EOF'
server {
    listen 80;
    server_name VPS_FQDN;
    location /.well-known/acme-challenge/ { root /var/www/letsencrypt; }
    location / { return 301 https://$host$request_uri; }
}
EOF
sudo sed -i 's/VPS_FQDN/mcr.pomeroy.us/' /etc/nginx/conf.d/corescope-http.conf   # your real name
sudo nginx -t && sudo systemctl enable --now nginx


# step 3

sudo certbot certonly --webroot -w /var/www/letsencrypt -d mcr.pomeroy.us \
  -m allen@pomeroy.us --agree-tos --no-eff-email \
  --deploy-hook "systemctl reload nginx"
sudo systemctl enable --now certbot-renew.timer
systemctl list-timers | grep certbot
sudo certbot renew --dry-run


# step 4

sudo install -d -m 750 -o root -g nginx /etc/nginx/corescope
sudo htpasswd -c -B /etc/nginx/corescope/htpasswd apomeroy # -c only for the first user; it prompts for the password
sudo htpasswd -B /etc/nginx/corescope/htpasswd malko       # each further user, without -c
sudo chown root:nginx /etc/nginx/corescope/htpasswd && sudo chmod 640 /etc/nginx/corescope/htpasswd
sudo restorecon -Rv /etc/nginx/corescope


# step 5

sudo tee /etc/nginx/conf.d/corescope.conf >/dev/null <<'EOF'
map $http_upgrade $cs_connection_upgrade {
    default upgrade;
    ''      close;
}
server {
    listen 443 ssl;
    server_name mcr.pomeroy.us;

    ssl_certificate      /etc/letsencrypt/live/VPS_FQDN/fullchain.pem;
    ssl_certificate_key  /etc/letsencrypt/live/VPS_FQDN/privkey.pem;
    ssl_protocols        TLSv1.2 TLSv1.3;

    auth_basic           "CoreScope";
    auth_basic_user_file /etc/nginx/corescope/htpasswd;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $http_host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $cs_connection_upgrade;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
    }
}
EOF
sudo sed -i 's/VPS_FQDN/mcr.pomeroy.us/g' /etc/nginx/conf.d/corescope.conf      # your real name
sudo setsebool -P httpd_can_network_connect 1
sudo nginx -t && sudo systemctl reload nginx


# step 6



