{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "{{SYNAPSE_PUBLIC_BASEURL_TRIMMED}}",
      "server_name": "{{SYNAPSE_DOMAIN}}"
    },
    "m.identity_server": {
      "base_url": "{{MATRIX_IDENTITY_SERVER}}"
    }
  },
  "disable_custom_urls": true,
  "brand": "{{ELEMENT_BRAND}}",
  "integrations_ui_url": "{{ELEMENT_INTEGRATIONS_UI_URL}}",
  "integrations_rest_url": "{{ELEMENT_INTEGRATIONS_REST_URL}}",
  "integrations_widgets_urls": [
    "{{ELEMENT_INTEGRATIONS_WIDGETS_URL_1}}",
    "{{ELEMENT_INTEGRATIONS_WIDGETS_URL_2}}",
    "{{ELEMENT_INTEGRATIONS_WIDGETS_URL_3}}",
    "{{ELEMENT_INTEGRATIONS_WIDGETS_URL_4}}",
    "{{ELEMENT_INTEGRATIONS_WIDGETS_URL_5}}"
  ],
  "bug_report_endpoint_url": "{{ELEMENT_BUG_REPORT_ENDPOINT_URL}}",
  "uisi_autorageshake_app": "{{ELEMENT_UISI_AUTORAGESHAKE_APP}}",
  "showLabsSettings": {{ELEMENT_SHOW_LABS_SETTINGS}},
  "roomDirectory": {
    "servers": [
      "{{ELEMENT_ROOM_DIRECTORY_SERVER_1}}",
      "{{ELEMENT_ROOM_DIRECTORY_SERVER_2}}",
      "{{ELEMENT_ROOM_DIRECTORY_SERVER_3}}"
    ]
  },
  "enable_presence_by_hs_url": {
    "https://matrix.org": false,
    "{{SYNAPSE_PUBLIC_BASEURL_TRIMMED}}": false
  },
  "terms_and_conditions_links": [
    {
      "url": "{{ELEMENT_TERMS_URL_1}}",
      "text": "{{ELEMENT_TERMS_TEXT_1}}"
    },
    {
      "url": "{{ELEMENT_TERMS_URL_2}}",
      "text": "{{ELEMENT_TERMS_TEXT_2}}"
    }
  ],
  "posthog": {
    "projectApiKey": "{{ELEMENT_POSTHOG_PROJECT_API_KEY}}",
    "apiHost": "{{ELEMENT_POSTHOG_API_HOST}}"
  },
  "privacy_policy_url": "{{ELEMENT_PRIVACY_POLICY_URL}}",
  "map_style_url": "{{ELEMENT_MAP_STYLE_URL}}"
}
