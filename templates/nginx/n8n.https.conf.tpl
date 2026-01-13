server {
    listen 80;
    server_name ${N8N_DOMAIN};
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${N8N_DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${N8N_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${N8N_DOMAIN}/privkey.pem;

    client_max_body_size 64m;

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
