Redis Docker Setup Script

This script sets up a Redis server using Docker for the **Netsepio** project.

## 📄 File: `docker.redis.sh`

### ✅ What It Does

* Pulls the official Redis Docker image.
* Creates a persistent volume for Redis data.
* Runs a Redis container with custom configurations and exposes the necessary port.
* Ensures Redis is always restarted unless manually stopped.

### 📦 Docker Configuration Details

* **Image** : `redis:latest`
* **Container Name** : `netsepio-redis`
* **Port** : `6379:6379` (host:container)
* **Volume** : `redis_data:/data`
* **Restart Policy** : `unless-stopped`

### 🛠️ How to Use

1. Make the script executable:
   ```bash
   chmod +x docker.redis.sh
   ```
2. Run the script:
   ```bash
   ./docker.redis.sh
   ```

### 📁 Script Breakdown

```bash
#!/bin/bash

docker volume create redis_data

docker run -d \
  --name netsepio-redis \
  -p 6379:6379 \
  -v redis_data:/data \
  --restart unless-stopped \
  redis:latest
```

### ⚠️ Requirements

* Docker installed and running.
* Permissions to run Docker commands (`sudo` may be needed depending on your setup).
