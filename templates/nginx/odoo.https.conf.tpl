server {
    listen 80;
    server_name ${ODOO_DOMAIN};
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
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
        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_pass http://127.0.0.1:${ODOO_LONGPOLL_HOST_PORT};
        proxy_redirect off;
    }

    gzip on;
    gzip_types text/css text/plain application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
