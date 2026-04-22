# Production Monitoring Stack – Deployment Guide

A complete guide to deploying Prometheus + Grafana + Alertmanager + Traefik
across a central server and unlimited remote servers using Docker on Ubuntu 22.04.

---

## Folder Structure

```
monitoring-stack/
├── central/                          ← Deploy on your central monitoring server
│   ├── docker-compose.yml
│   ├── .env.example                  ← Copy to .env and fill in secrets
│   ├── prometheus/
│   │   ├── prometheus.yml            ← Scrape configs + labels
│   │   ├── rules/
│   │   │   └── alert-rules.yml       ← CPU / memory / disk / container alerts
│   │   └── sd/                       ← Drop target JSON files here (file SD)
│   ├── alertmanager/
│   │   ├── alertmanager.yml          ← Routing + Teams webhook config
│   │   └── teams-payload-example.json
│   ├── traefik/
│   │   └── dynamic/
│   │       └── middlewares.yml       ← Basic auth + IP allowlist + headers
│   └── grafana/
│       └── provisioning/
│           ├── datasources/
│           │   └── prometheus.yml    ← Auto-provisions Prometheus datasource
│           └── dashboards/
│               └── dashboards.yml    ← Auto-imports dashboard JSON files
└── remote/                           ← Deploy on every server you want monitored
    └── docker-compose.yml
```

---

## Prerequisites (all servers)

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose plugin
sudo apt-get install -y docker-compose-plugin

# Verify
docker --version && docker compose version
```

---

## Step 1 – Deploy Remote Exporters

Run this on **every server** you want to monitor.

```bash
# Copy the remote docker-compose.yml to the server
scp remote/docker-compose.yml user@10.0.1.10:/opt/monitoring/

# SSH in and start exporters
ssh user@10.0.1.10
cd /opt/monitoring
docker compose up -d

# Verify exporters are running
curl -s http://localhost:9100/metrics | head -5   # Node Exporter
curl -s http://localhost:8080/metrics | head -5   # cAdvisor
```

---

## Step 2 – Firewall Rules (Remote Servers)

Allow only the **central server** to scrape the exporters.
Replace `CENTRAL_SERVER_IP` with your actual IP.

```bash
# UFW (Ubuntu)
CENTRAL_IP="10.0.0.5"   # ← your central server's private IP

sudo ufw allow from $CENTRAL_IP to any port 9100 proto tcp comment "Prometheus Node Exporter"
sudo ufw allow from $CENTRAL_IP to any port 8080 proto tcp comment "Prometheus cAdvisor"
sudo ufw deny  9100
sudo ufw deny  8080
sudo ufw reload

# Verify
sudo ufw status numbered
```

**AWS Security Group rules** (add as inbound rules):
```
Type        Protocol  Port  Source
Custom TCP  TCP       9100  sg-central-server (or 10.0.0.5/32)
Custom TCP  TCP       8080  sg-central-server (or 10.0.0.5/32)
```

---

## Step 3 – Configure Prometheus Targets

Edit `central/prometheus/prometheus.yml` and add your server IPs:

```yaml
# Production servers
- targets:
    - '10.0.1.10:9100'    # prod-app-01
    - '10.0.1.11:9100'    # prod-app-02
  labels:
    environment: 'prod'
```

**To add servers dynamically (no restart required)**, use file-based SD.
Drop a JSON file into `central/prometheus/sd/`:

```bash
cat > central/prometheus/sd/new-prod-server.json << 'EOF'
[
  {
    "targets": ["10.0.1.20:9100", "10.0.1.20:8080"],
    "labels": {
      "environment": "prod",
      "hostname":    "prod-app-04",
      "role":        "web"
    }
  }
]
EOF
# Prometheus picks this up within 30 seconds – no restart needed.
```

---

## Step 4 – Generate Traefik Basic Auth Password

```bash
# Install htpasswd
sudo apt-get install -y apache2-utils

# Generate hash for user 'admin' with your chosen password
htpasswd -nbB admin 'YourSecurePassword!'
# Output: admin:$2y$05$...

# In traefik/dynamic/middlewares.yml, paste the hash and escape $ as $$:
# admin:$$2y$$05$$...
```

---

## Step 5 – Configure MS Teams Webhook

### Create the Incoming Webhook in Teams:

1. Open **Microsoft Teams** → go to the target channel
2. Click **⋯ (More options)** → **Connectors**
3. Search for **"Incoming Webhook"** → click **Configure**
4. Give it a name (e.g., "Prometheus Alerts") and optionally upload an icon
5. Click **Create** → copy the generated webhook URL
6. Click **Done**

The URL looks like:
```
https://mycompany.webhook.office.com/webhookb2/GUID@GUID/IncomingWebhook/TOKEN/GUID
```

### Install prometheus-msteams (bridges Alertmanager → Teams Adaptive Cards)

Alertmanager sends its own JSON format; Teams expects Adaptive Cards.
The `prometheus-msteams` proxy handles the translation:

```bash
# On the central server, add to docker-compose.yml:
  prometheus-msteams:
    image: bzon/prometheus-msteams:latest
    container_name: prometheus-msteams
    restart: unless-stopped
    environment:
      - TEAMS_INCOMING_WEBHOOK_URL=https://mycompany.webhook.office.com/webhookb2/YOUR_URL
      - TEAMS_REQUEST_URI=alertmanager
    ports:
      - "2000:2000"
    networks:
      - monitoring
```

Then update `alertmanager.yml` to point to this proxy:
```yaml
receivers:
  - name: 'teams-critical'
    webhook_configs:
      - url: 'http://prometheus-msteams:2000/alertmanager'
        send_resolved: true
```

### Test the webhook manually:

```bash
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "message",
    "attachments": [{
      "contentType": "application/vnd.microsoft.card.adaptive",
      "content": {
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        "type": "AdaptiveCard",
        "version": "1.4",
        "body": [{"type":"TextBlock","text":"✅ Test alert from Prometheus","weight":"Bolder"}]
      }
    }]
  }' \
  'https://mycompany.webhook.office.com/webhookb2/YOUR_WEBHOOK_URL'
```

---

## Step 6 – Deploy the Central Server

```bash
# On the central monitoring server
cd /opt/monitoring-stack/central

# Copy and fill in secrets
cp .env.example .env
nano .env   # set GRAFANA_ADMIN_PASSWORD etc.

# Start all services
docker compose up -d

# Follow logs
docker compose logs -f

# Verify all containers are healthy
docker compose ps
```

---

## Step 7 – DNS Configuration

Point your domains to the central server's public IP:

```
monitoring.mycompany.com    A   <CENTRAL_SERVER_PUBLIC_IP>
prometheus.mycompany.com    A   <CENTRAL_SERVER_PUBLIC_IP>
alertmanager.mycompany.com  A   <CENTRAL_SERVER_PUBLIC_IP>
traefik.mycompany.com       A   <CENTRAL_SERVER_PUBLIC_IP>
```

Traefik will automatically obtain Let's Encrypt certificates
for all four domains within 60–90 seconds of first request.

---

## Step 8 – Grafana Setup

### Access Grafana
```
URL:      https://monitoring.mycompany.com
Username: admin
Password: (from .env → GRAFANA_ADMIN_PASSWORD)
```

The Prometheus datasource is **auto-provisioned** — no manual config needed.

### Import Popular Dashboards

Go to **Dashboards → Import** and enter these dashboard IDs:

| Dashboard                     | ID    | URL |
|-------------------------------|-------|-----|
| Node Exporter Full            | 1860  | https://grafana.com/grafana/dashboards/1860 |
| Node Exporter Quickstart      | 13978 | https://grafana.com/grafana/dashboards/13978 |
| cAdvisor / Docker             | 14282 | https://grafana.com/grafana/dashboards/14282 |
| Docker Container & Host Stats | 10619 | https://grafana.com/grafana/dashboards/10619 |
| Traefik v3                    | 17346 | https://grafana.com/grafana/dashboards/17346 |
| Alertmanager                  | 9578  | https://grafana.com/grafana/dashboards/9578  |

**Import steps:**
1. Click **Dashboards → New → Import**
2. Enter the ID number → click **Load**
3. Select **Prometheus** as the data source
4. Click **Import**

---

## Step 9 – Verify Prometheus Targets

```
https://prometheus.mycompany.com/targets
```

All targets should show **State: UP** (green).
If any show DOWN, check the Troubleshooting section below.

---

## Reload Configs Without Restart

```bash
# Reload Prometheus config (no downtime)
curl -X POST http://localhost:9090/-/reload

# Reload Alertmanager config
curl -X POST http://localhost:9093/-/reload

# Verify rules are loaded
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].name'
```

---

## Scaling to 100+ Servers

### Service Discovery Options

**1. File-based SD (recommended for 10–50 servers)**
- No extra infrastructure needed
- Ansible/Terraform drops target JSON files into `/etc/prometheus/sd/`
- Prometheus picks up changes within 30 seconds

```bash
# Ansible task to register a new server
- name: Register server with Prometheus
  template:
    src: prometheus-target.json.j2
    dest: /opt/monitoring/central/prometheus/sd/{{ inventory_hostname }}.json
  delegate_to: monitoring-central
```

**2. HTTP SD (50–500 servers)**
- Prometheus polls an HTTP endpoint that returns target JSON
- Implement a simple API (or use Consul) that returns current server list

```yaml
- job_name: 'http-sd'
  http_sd_configs:
    - url: 'http://your-cmdb-api/prometheus/targets'
      refresh_interval: 30s
```

**3. Cloud-based SD (AWS / GCP / Azure)**

```yaml
# AWS EC2 auto-discovery – tags all EC2 instances automatically
- job_name: 'aws-ec2'
  ec2_sd_configs:
    - region: us-east-1
      port:    9100
      filters:
        - name: "tag:monitoring"
          values: ["enabled"]
  relabel_configs:
    - source_labels: [__meta_ec2_tag_Environment]
      target_label:  environment
    - source_labels: [__meta_ec2_private_ip_address]
      replacement:   '$1:9100'
      target_label:  __address__
```

### Scaling Prometheus Storage

For > 50 servers / > 30 days retention, consider:

- **Thanos** – horizontally scalable Prometheus with long-term object storage (S3/GCS)
- **Cortex / Mimir** – multi-tenant Prometheus with remote write
- **VictoriaMetrics** – drop-in Prometheus replacement with better compression

```yaml
# Enable remote write in prometheus.yml (for Thanos/Mimir/VictoriaMetrics)
remote_write:
  - url: "http://thanos-receive:19291/api/v1/receive"
```

---

## Troubleshooting

### Prometheus targets show DOWN

```bash
# 1. Check the target's exporter is running
ssh user@10.0.1.10 "docker ps | grep -E 'node-exporter|cadvisor'"

# 2. Test connectivity from central server
curl -v http://10.0.1.10:9100/metrics
curl -v http://10.0.1.10:8080/metrics

# 3. Check firewall
ssh user@10.0.1.10 "sudo ufw status | grep -E '9100|8080'"

# 4. Check Prometheus logs
docker logs prometheus --tail 50

# 5. Verify prometheus.yml syntax
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### No metrics in Grafana

```bash
# 1. Verify datasource in Grafana UI:
#    Settings → Data Sources → Prometheus → Save & Test → should show green tick

# 2. Test a raw query in Grafana Explore:
#    up{job="node-exporter-prod"}

# 3. Check Prometheus has data:
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result'

# 4. Check Grafana can reach Prometheus (inside Docker network):
docker exec grafana wget -qO- http://prometheus:9090/-/healthy
```

### Traefik routing issues

```bash
# 1. Check Traefik dashboard for routing errors:
#    https://traefik.mycompany.com

# 2. Check TLS certificates:
docker exec traefik cat /certs/acme.json | jq '.letsencrypt.Certificates[].domain'

# 3. View Traefik access logs:
docker logs traefik --tail 100 | grep -v "200"

# 4. Test HTTP → HTTPS redirect:
curl -vI http://monitoring.mycompany.com

# 5. Check DNS resolution:
dig monitoring.mycompany.com +short
```

### Teams webhook not triggering

```bash
# 1. Trigger a test alert manually in Alertmanager:
curl -X POST http://localhost:9093/api/v2/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {"alertname":"TestAlert","severity":"critical","environment":"prod"},
    "annotations": {"summary":"Test alert","description":"Manual test"}
  }]'

# 2. Check Alertmanager received it:
curl -s http://localhost:9093/api/v2/alerts | jq '.[].labels'

# 3. Check Alertmanager logs:
docker logs alertmanager --tail 50

# 4. Verify webhook URL is correct in alertmanager.yml:
docker exec alertmanager cat /etc/alertmanager/alertmanager.yml | grep url

# 5. Test webhook directly:
curl -X POST -H 'Content-Type: application/json' \
  -d '{"type":"message","text":"Test"}' \
  'YOUR_TEAMS_WEBHOOK_URL'
```

### Exporter connectivity issues

```bash
# Restart a specific exporter
docker compose -f /opt/monitoring/docker-compose.yml restart node-exporter

# Check exporter resource usage
docker stats node-exporter cadvisor

# Check exporter logs
docker logs node-exporter --tail 50
docker logs cadvisor --tail 50

# Verify metrics endpoint is serving
curl -s http://localhost:9100/metrics | grep node_cpu_seconds_total
```

---

## Security Checklist

- [ ] Change default Grafana admin password (set in `.env`)
- [ ] Generate strong htpasswd hash for Traefik basic auth
- [ ] Restrict Prometheus and Alertmanager with IP allowlist
- [ ] Firewall rules: only allow central server to reach exporters (ports 9100, 8080)
- [ ] Never expose ports 9100/8080/9090/9093 publicly
- [ ] Rotate `.env` secrets regularly
- [ ] Set `GF_USERS_ALLOW_SIGN_UP=false` in Grafana (already set)
- [ ] Enable Let's Encrypt TLS (already configured via Traefik)
- [ ] Add HSTS headers (done via secure-headers middleware)
- [ ] Store `.env` in a secrets manager (AWS Secrets Manager, Vault, etc.) in production
