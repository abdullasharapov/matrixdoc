http:
  middlewares:
    secureHeaders:
      headers:
        sslRedirect: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000

    middlewares-rate-limit:
      rateLimit:
        average: 100
        burst: 50

    middlewares-secure-headers:
      headers:
        accessControlAllowMethods:
          - GET
          - OPTIONS
          - PUT
        accessControlMaxAge: 100
        hostsProxyHeaders:
          - "X-Forwarded-Host"
        stsSeconds: 63072000
        stsIncludeSubdomains: true
        stsPreload: true
        customFrameOptionsValue: SAMEORIGIN
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "same-origin"
        permissionsPolicy: "camera=(), microphone=(), geolocation=(), payment=(), usb=(), vr=()"
        customResponseHeaders:
          X-Robots-Tag: "none,noarchive,nosnippet,notranslate,noimageindex,"
          x-powered-by: ""
          server: ""
    autodetectContenttype:
      contentType: {}

tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
        - TLS_AES_128_GCM_SHA256
        - TLS_AES_256_GCM_SHA384
        - TLS_CHACHA20_POLY1305_SHA256
      curvePreferences:
        - CurveP521
        - CurveP384