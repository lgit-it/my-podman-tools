server {
    listen 80;
    server_name ${N8N_DOMAIN};

    client_max_body_size 64m;

    # ACME webroot (Let's Encrypt)
    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type "text/plain";
    }

    location / {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_pass http://127.0.0.1:${N8N_HOST_PORT};
        proxy_redirect off;
    }
}
