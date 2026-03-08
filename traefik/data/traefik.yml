api:
  dashboard: true

entryPoints:
  web:
    address: :80
    http:
      redirections:
        entryPoint:
          to: websecure

  websecure:
    address: :443

  metrics:
    address: :8082

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: /custom
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@admin.com
      storage: acme.json
      tlschallenge: true
      httpChallenge:
        entryPoint: web

metrics:
  prometheus:
    entryPoint: metrics