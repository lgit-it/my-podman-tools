server {
    listen 80;
    server_name ${ODOO_DOMAIN};

    # REQUIRED: Allows Certbot to renew certificates via webroot
    location /.well-known/acme-challenge/ {
        root /srv/containers/nginx/www;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    # Fixed: Moved http2 to its own directive (Nginx 1.25.1+ compatibility)
    listen 443 ssl;
    http2 on;

    server_name ${ODOO_DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${ODOO_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${ODOO_DOMAIN}/privkey.pem;

    client_max_body_size 64m;

    location / {
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;

        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_pass http://127.0.0.1:${ODOO_HOST_PORT};
        proxy_redirect off;
    }

    location /longpolling {
        # Added: Explicit WebSocket/Upgrade support for Odoo live notifications
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_pass http://127.0.0.1:${ODOO_LONGPOLL_HOST_PORT};
        proxy_redirect off;
    }

    gzip on;
    gzip_types text/css text/plain application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}