# 📦 PostgreSQL Dump Restore (Docker + Role Handling)

## 🎯 Objective

Restore a production PostgreSQL dump into a local Docker container **without errors related to roles, ownership, or permissions**.

---

# 🧠 Problem Overview

When restoring a dump, you may see errors like:

* `role "cyrene-prod-user" does not exist`
* `role "postgres" does not exist`
* `role "anon" does not exist`

👉 This happens because:

* Dump contains **role ownership + grants**
* Local DB does not have those roles

---

# ✅ Solution Approaches

## 🟢 Approach 1 (Recommended - Production Accurate)

1. Extract roles from dump
2. Create roles locally
3. Restore dump

## 🟡 Approach 2 (Quick Testing)

Skip ownership + privileges:

```bash
psql --no-owner --no-privileges
```

---

# 🔍 Step 1: Extract Roles from Dump

### Command:

```bash
ggrep -oP 'OWNER TO "\K[^"]+' 2026-03-31_22-30_prod.sql | sort | uniq
```

Also extract roles from GRANT:

```bash
ggrep -oP 'TO "\K[^"]+' 2026-03-31_22-30_prod.sql | sort | uniq
```

---

# 🤖 AI Prompt (for role extraction)

```
I have a PostgreSQL dump file. Extract all unique roles used in OWNER TO and GRANT TO statements and return a clean list.
```

---

# 🔧 Step 2: Create Required Roles

## Minimal roles (example):

```sql
CREATE ROLE "cyrene-prod-user";
CREATE ROLE postgres;
CREATE ROLE vultradmin_group;
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role;
```

---

## 🤖 AI Prompt (for role creation)

```
Given this list of PostgreSQL roles, generate SQL to safely create them only if they don’t exist.
```

---

# 🧹 Step 3: Clean Database (Important)

```bash
docker exec -it <container_id> psql -U inteluser -d "cyrene-test-dump" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

---

## 🤖 AI Prompt

```
Give me a PostgreSQL command to completely reset a schema before restoring a dump.
```

---

# 🚀 Step 4: Restore Dump

```bash
docker exec -i <container_id> psql -U inteluser -d "cyrene-test-dump" < 2026-03-31_22-30_prod.sql
```

---

## 🤖 AI Prompt

```
Give me a Docker command to restore a PostgreSQL dump into a container database.
```

---

# ⚡ Alternative: Ignore Roles (Quick Method)

```bash
docker exec -i <container_id> psql -U inteluser -d "cyrene-test-dump" --no-owner --no-privileges < dump.sql
```

---

## 🤖 AI Prompt

```
How can I restore a PostgreSQL dump while ignoring ownership and permissions?
```

---

# ✅ Step 5: Verify Restore

```bash
docker exec -it <container_id> psql -U inteluser -d "cyrene-test-dump" -c "\dt"
```

---

## 🤖 AI Prompt

```
How can I verify if a PostgreSQL dump restored successfully?
```

---

# ⚠️ Common Issues & Fixes

### ❌ Role does not exist

👉 Create missing roles before restore

---

### ❌ Permission denied

👉 Use:

```bash
--no-owner --no-privileges
```

---

### ❌ wal_level warning

👉 Ignore for local testing

---

# 🔥 Best Practices

* Always use:

```bash
pg_dump --no-owner --no-privileges
```

* Keep dumps **portable**
* Avoid environment-specific dependencies

---

# 🧠 Key Insight

PostgreSQL dump =
👉 Data + Schema + Ownership + Permissions

Restore fails when:
👉 Local environment ≠ Production environment

---

# 🚀 Advanced Automation Idea

Create a script:

```bash
extract_roles → create_roles → clean_db → restore_dump
```

---

## 🤖 AI Prompt (Automation)

```
Create a bash script that extracts PostgreSQL roles from a dump, creates them, and restores the dump into a Docker container.
```

---

# ✅ Summary

| Step | Action        |
| ---- | ------------- |
| 1    | Extract roles |
| 2    | Create roles  |
| 3    | Clean DB      |
| 4    | Restore dump  |
| 5    | Verify        |

---

✔ Your dump is valid
✔ Errors were due to missing roles
✔ Fix = environment replication

---

# 💬 Final Note

If you're:

* debugging → use roles
* testing → skip roles

---

END
