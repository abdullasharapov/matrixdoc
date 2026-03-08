http:
  routers:
    coturn_https:
      entryPoints:
      - websecure
      service: coturn
      rule: "Host(`${TURN_DOMAIN}`)"
      tls:
        certResolver: letsencrypt

  services:
    coturn:
      loadBalancer:
        servers:
          - url: "http://172.17.0.1:${TURN_TLS_PORT}"