server {
    listen 80;
    server_name ${N8N_DOMAIN};

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
    # Fixed: Removed 'http2' from the listen line to resolve deprecation warning
    listen 443 ssl;
    http2 on; 

    server_name ${N8N_DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${N8N_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${N8N_DOMAIN}/privkey.pem;

    client_max_body_size 64m;

    location / {
        proxy_http_version 1.1;
        
        # Corrected: Standard WebSocket upgrade headers for n8n
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        include /etc/nginx/snippets/proxy-headers.conf;
        proxy_pass http://127.0.0.1:${N8N_HOST_PORT};
        proxy_redirect off;
    }
}