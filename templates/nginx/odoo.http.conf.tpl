server {
    listen 80;
    server_name ${ODOO_DOMAIN};

    client_max_body_size 64m;

    # ACME webroot (Let's Encrypt)
    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
    }

    location / {
        proxy_read_timeout 720s;
        proxy_connect_timeout 720s;
        proxy_send_timeout 720s;

        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_pass http://127.0.0.1:${ODOO_HOST_PORT};
        proxy_redirect off;
    }

    location /longpolling {
        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_pass http://127.0.0.1:${ODOO_LONGPOLL_HOST_PORT};
        proxy_redirect off;
    }

    gzip on;
    gzip_types text/css text/plain application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
