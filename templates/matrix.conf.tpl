server {
    listen 80 default_server;
    server_name {{SYNAPSE_DOMAIN}};

    location /_matrix {
        proxy_pass http://synapse-app:8008;
        proxy_set_header X-Forwarded-For $$remote_addr;
        client_max_body_size {{NGINX_CLIENT_MAX_BODY_SIZE}};
    }

    location /.well-known/matrix/server {
        access_log off;
        add_header Access-Control-Allow-Origin *;
        default_type application/json;
        return 200 '{"m.server": "{{SYNAPSE_DOMAIN}}:443"}';
    }

    location /.well-known/matrix/client {
        access_log off;
        add_header Access-Control-Allow-Origin *;
        default_type application/json;
        return 200 '{"m.homeserver":{"base_url":"{{SYNAPSE_PUBLIC_BASE_URL}}"}, "org.matrix.msc4143.rtc_foci":[{"type":"livekit", "livekit_service_url":"https://{{LIVEKIT_BASE_URL}}/livekit/jwt"}]}';
    }

    location /metrics {
        proxy_pass http://synapse-app:8084/_synapse/metrics;
        proxy_set_header X-Forwarded-For $$remote_addr;
        client_max_body_size {{NGINX_CLIENT_MAX_BODY_SIZE}};
    }
}
