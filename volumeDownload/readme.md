* What the script does
* How it works
* Cron configuration
* Log location
* How to stop/disable it
* Retention policy
* Folder structure

You can save this as:

```
/root/README_BACKUP_PROCESS.md
```

---

# 📦 Docker Volume Backup Automation – Cyrene IPFS

## 📌 Overview

This setup automates daily backups of Docker volumes from a remote production server.

Backed-up volumes:

* `ipfs_data`
* `ipfs_staging`
* `ipfs_volume`

The system:

* Runs daily at **2:00 AM**
* Performs backups in **parallel**
* Stores backups in per-volume folders
* Keeps only **last 7 days**
* Logs execution output
* Cleans old backups automatically

---

# 🛠 Architecture

## 🔹 Source Server

```
45.77.31.190
```

* Contains Docker volumes
* Backup is created remotely using `tar`

## 🔹 Backup Server

```
CyreneNetsepioVolumes
```

* Stores backup archives
* Runs cron job
* Maintains retention policy

---

# 📂 Backup Directory Structure

Backups are stored at:

```
$HOME/backup-cyrene/ipfs/
```

Structure:

```
ipfs/
    ipfs_data/
        ipfs_data_2026-02-18_02-00-01.tar.gz
        ipfs_data_2026-02-19_02-00-01.tar.gz

    ipfs_staging/
        ipfs_staging_2026-02-18_02-00-01.tar.gz

    ipfs_volume/
        ipfs_volume_2026-02-18_02-00-01.tar.gz
```

Each run:

* Creates a timestamped `.tar.gz`
* Keeps volume names unchanged
* Deletes files older than 7 days

---

# ⚙️ Script Location

```
/root/backup_ipfs_volumes_pro.sh
```

---

# 🔍 What the Script Does

For each volume:

1. Connects to remote server via SSH
2. Gets Docker volume mount path
3. Creates a compressed archive:

   ```
   tar -czf /tmp/volume_timestamp.tar.gz
   ```
4. Downloads archive via `scp`
5. Removes remote temporary file
6. Deletes backups older than 7 days
7. Runs multiple volumes in parallel

---

# ⚡ Parallel Execution

Controlled by:

```
PARALLEL_JOBS=3
```

This allows up to 3 volumes to process simultaneously for faster execution.

---

# 🔁 Retention Policy

```
RETENTION_DAYS=7
```

Command used:

```
find ... -mtime +7 -delete
```

Only backups older than 7 days are removed.

---

# ⏰ Cron Job Configuration

Cron is configured under root:

```
crontab -l
```

Current entry:

```
0 2 * * * /root/backup_ipfs_volumes_pro.sh >> /var/log/ipfs_backup.log 2>&1
```

Meaning:

* Runs daily at 2:00 AM
* Appends logs to:

  ```
  /var/log/ipfs_backup.log
  ```

---

# 📜 Where Logs Are Stored

```
/var/log/ipfs_backup.log
```

To check logs:

```
cat /var/log/ipfs_backup.log
```

Or live monitoring:

```
tail -f /var/log/ipfs_backup.log
```

---

# 🛑 How To Stop the Backup Process

## 🔹 Stop Immediately (If Running Now)

Find process:

```
ps aux | grep backup_ipfs_volumes_pro.sh
```

Kill it:

```
kill -9 <PID>
```

---

## 🔹 Disable Future Cron Execution

Open cron:

```
crontab -e
```

Comment the line:

```
# 0 2 * * * /root/backup_ipfs_volumes_pro.sh >> /var/log/ipfs_backup.log 2>&1
```

Save and exit.

Verify:

```
crontab -l
```

---

## 🔹 Completely Remove Cron Job

Inside crontab:

Delete the line completely.

---

# ▶️ Manual Execution

To run manually:

```
/root/backup_ipfs_volumes_pro.sh
```

---

# 🧪 Testing Mode

To temporarily run every 2 minutes:

```
*/2 * * * * /root/backup_ipfs_volumes_pro.sh >> /var/log/ipfs_backup.log 2>&1
```

Revert to production schedule after testing.

---

# 🔐 Security Notes

* Script runs as root
* SSH must be key-based (recommended)
* Remote server must allow SSH access
* Ensure sufficient disk space

---

# 📊 Monitoring

Check disk usage:

```
df -h
```

Check cron status:

```
systemctl status cron
```

---

# 🚀 Current Production Capabilities

✔ Automated daily backup
✔ Parallel execution
✔ 7-day retention
✔ Centralized logging
✔ Remote Docker volume backup
✔ Clean per-volume storage structure

---

# 📌 Recovery Process (High-Level)

To restore a volume:

```
docker volume create ipfs_data

docker run --rm \
  -v ipfs_data:/data \
  -v /path/to/backup:/backup \
  alpine \
  sh -c "cd /data && tar -xzf /backup/ipfs_data_timestamp.tar.gz"
```

---

# 📅 Maintenance Recommendations

* Check disk usage weekly
* Monitor log file size
* Periodically test restore procedure
* Consider secondary offsite backup

---

# 🏁 Status

This setup is:

* Stable
* Automated
* Production-ready
* Clean and maintainable

---

If you want, I can now:

* Convert this into a GitHub-style README
* Generate a PDF version
* Create a disaster recovery SOP document
* Add a restore automation script documentation

Just tell me the level you want 👌
