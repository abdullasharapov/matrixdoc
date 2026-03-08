server_name: "{{SYNAPSE_DOMAIN}}"
public_baseurl: {{SYNAPSE_PUBLIC_BASEURL}}
pid_file: /data/homeserver.pid

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false
    bind_addresses: ['0.0.0.0']

  - port: 8084
    type: metrics
    bind_addresses: ['0.0.0.0']

database:
  name: psycopg2
  args:
    user: {{POSTGRES_USER}}
    password: {{POSTGRES_PASSWORD}}
    database: {{POSTGRES_DB}}
    host: synapse-db

log_config: "/data/{{SYNAPSE_DOMAIN}}.log.config"
media_store_path: /data/media_store
max_upload_size: {{MAX_UPLOAD_SIZE}}
max_image_pixels: {{MAX_IMAGE_PIXELS}}

registration_shared_secret: "{{REGISTRATION_SHARED_SECRET}}"
report_stats: {{SYNAPSE_REPORT_STATS}}
macaroon_secret_key: "{{MACAROON_SECRET_KEY}}"
form_secret: "{{FORM_SECRET}}"
signing_key_path: "/data/{{SYNAPSE_DOMAIN}}.signing.key"

trusted_key_servers:
  - server_name: "{{TRUSTED_KEY_SERVER}}"

enable_3pid_changes: {{ENABLE_3PID_CHANGES}}

enable_registration: {{ENABLE_REGISTRATION}}

enable_metrics: {{ENABLE_METRICS}}

email:
  smtp_host: {{SMTP_HOST}}
  smtp_port: {{SMTP_PORT}}
  smtp_user: "{{SMTP_USER}}"
  smtp_pass: "{{SMTP_PASS}}"
  notif_from: "{{SMTP_FROM}}"
  enable_notifs: {{SMTP_ENABLE_NOTIFS}}
  validation_token_lifetime: {{SMTP_VALIDATION_TOKEN_LIFETIME}}

turn_uris:
  - "turn:{{TURN_DOMAIN}}:{{TURN_TLS_PORT}}?transport=udp"
turn_shared_secret: "{{TURN_SHARED_SECRET}}"
turn_user_lifetime: {{TURN_USER_LIFETIME}}
turn_allow_guests: {{TURN_ALLOW_GUESTS}}

experimental_features:
  msc3266_enabled: {{MSC3266_ENABLED}}
  msc4222_enabled: {{MSC4222_ENABLED}}
  msc4140_enabled: {{MSC4140_ENABLED}}

max_event_delay_duration: {{MAX_EVENT_DELAY_DURATION}}

rc_message:
  per_second: {{RC_MESSAGE_PER_SECOND}}
  burst_count: {{RC_MESSAGE_BURST_COUNT}}

rc_delayed_event_mgmt:
  per_second: {{RC_DELAYED_EVENT_MGMT_PER_SECOND}}
  burst_count: {{RC_DELAYED_EVENT_MGMT_BURST_COUNT}}
