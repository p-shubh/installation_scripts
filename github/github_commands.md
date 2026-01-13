gh api repos/ans-mishra/neurolov_whitelabel/hooks \
  -X POST \
  --input - <<'EOF' | tee webhook-response.json
{
  "name": "web",
  "active": true,
  "events": ["*"],
  "config": {
    "url": "https://discord.com/api/webhooks/******************************/****************************************************/github",
    "content_type": "json",
    "insecure_ssl": "0"
  }
}
EOF