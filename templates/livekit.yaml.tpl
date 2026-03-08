port: {{LIVEKIT_PORT}}
bind_addresses:
  - "0.0.0.0"
rtc:
  tcp_port: {{LIVEKIT_TCP_PORT}}
  port_range_start: {{LIVEKIT_UDP_PORT_START}}
  port_range_end: {{LIVEKIT_UDP_PORT_END}}
  use_external_ip: {{LIVEKIT_USE_EXTERNAL_IP}}
room:
  auto_create: {{LIVEKIT_AUTO_CREATE}}
logging:
  level: {{LIVEKIT_LOG_LEVEL}}
turn:
  enabled: {{LIVEKIT_TURN_ENABLED}}
  domain: {{TURN_DOMAIN}}
  cert_file: ""
  key_file: ""
  tls_port: {{TURN_TLS_PORT}}
  udp_port: {{LIVEKIT_TURN_UDP_PORT}}
  external_tls: {{LIVEKIT_TURN_EXTERNAL_TLS}}
keys:
  {{LIVEKIT_KEY}}: "{{LIVEKIT_SECRET}}"
