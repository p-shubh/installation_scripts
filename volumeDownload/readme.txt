This version is suitable for:

* KT (Knowledge Transfer)
* Internal server documentation
* Simple text viewing via `cat` or `less`
* Sharing with team members

---

CYRENE IPFS DOCKER VOLUME BACKUP PROCESS
Production Backup Documentation (TXT Version)

---

1. OVERVIEW

This system performs automated daily backups of Docker volumes from a remote production server.

Volumes backed up:

* ipfs_data
* ipfs_staging
* ipfs_volume

Backup Characteristics:

* Runs daily at 2:00 AM
* Parallel execution
* 7-day retention policy
* Per-volume folder structure
* Logging enabled
* Fully automated via cron

---

2. SERVERS INVOLVED

Source Server (Docker Volumes)
IP: 45.77.31.190
Contains actual Docker volumes.
Backup archives are created remotely.

Backup Server
Hostname: CyreneNetsepioVolumes
Stores backup files.
Runs cron job.
Manages retention and logs.

---

3. SCRIPT LOCATION

/root/backup_ipfs_volumes_pro.sh

This script handles:

* SSH connection
* Docker volume inspection
* Tar archive creation
* SCP download
* Remote temp cleanup
* Retention management
* Parallel processing

---

4. BACKUP STORAGE LOCATION

$HOME/backup-cyrene/ipfs/

Directory structure:

backup-cyrene/ipfs/

```
ipfs_data/
    ipfs_data_YYYY-MM-DD_HH-MM-SS.tar.gz

ipfs_staging/
    ipfs_staging_YYYY-MM-DD_HH-MM-SS.tar.gz

ipfs_volume/
    ipfs_volume_YYYY-MM-DD_HH-MM-SS.tar.gz
```

Each execution:

* Creates a new timestamped tar.gz file
* Keeps volume name unchanged
* Deletes backups older than 7 days

---

5. CRON CONFIGURATION

Check cron:

crontab -l

Current configuration:

0 2 * * * /root/backup_ipfs_volumes_pro.sh >> /var/log/ipfs_backup.log 2>&1

Meaning:

* Runs every day at 2:00 AM
* Logs both output and errors

---

6. LOG FILE LOCATION

Log file:

/var/log/ipfs_backup.log

To view logs:

cat /var/log/ipfs_backup.log

Live monitoring:

tail -f /var/log/ipfs_backup.log

---

7. RETENTION POLICY

Configured in script:

RETENTION_DAYS=7

Command used:

find <volume-folder> -type f -name "*.tar.gz" -mtime +7 -delete

Backups older than 7 days are automatically deleted.

---

8. PARALLEL EXECUTION

Configured in script:

PARALLEL_JOBS=3

Up to 3 volumes can be processed simultaneously.
Improves backup speed.

---

9. MANUAL EXECUTION

To run backup manually:

/root/backup_ipfs_volumes_pro.sh

---

10. STOPPING THE BACKUP PROCESS

A. Stop Currently Running Backup

Find process:

ps aux | grep backup_ipfs_volumes_pro.sh

Kill process:

kill -9 <PID>

---

B. Disable Future Scheduled Backups

Edit cron:

crontab -e

Comment the line:

# 0 2 * * * /root/backup_ipfs_volumes_pro.sh >> /var/log/ipfs_backup.log 2>&1

Save and exit.

---

C. Completely Remove Cron Job

Delete the cron line inside crontab.

Verify:

crontab -l

---

11. CHECK CRON STATUS

systemctl status cron

Should show:
active (running)

---

12. DISK SPACE CHECK

Check available disk space:

df -h

Ensure enough space for 7 days of backups.

---

13. RESTORE PROCESS (HIGH LEVEL)

Example for restoring ipfs_data:

docker volume create ipfs_data

docker run --rm 
-v ipfs_data:/data 
-v /path/to/backup:/backup 
alpine 
sh -c "cd /data && tar -xzf /backup/ipfs_data_timestamp.tar.gz"

---

14. PRODUCTION STATUS

This setup provides:

* Automated daily backup
* Parallel processing
* 7-day automatic retention
* Centralized logging
* Clean per-volume structure
* Remote Docker volume backup
* Minimal manual intervention

---

15. MAINTENANCE RECOMMENDATIONS

* Monitor disk usage weekly
* Periodically check log file
* Test restore process occasionally
* Ensure SSH connectivity remains active

---

END OF DOCUMENTATION

---
