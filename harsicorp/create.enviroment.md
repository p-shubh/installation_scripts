# Vault KV v2 – Create, Use, Delete (CLI + UI)

This README is a **practical, end‑to‑end guide** for using **HashiCorp Vault KV v2** based on real CLI + UI behavior.

It covers:

* Creating a KV v2 secrets engine
* Writing & reading secrets
* Understanding CAS & versioning
* Correct deletion (why UI sometimes lies)

> **CLI is the source of truth. UI may cache results.**

---

## Prerequisites

* Vault running and unsealed
* Vault CLI installed locally
* Authenticated with a token that has:

  * `sys/mounts/*`
  * `<mount>/*` access

```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault login <VAULT_TOKEN>
```

---

## 1️⃣ Create a KV v2 Secrets Engine

Create a secrets engine named `cyrene_dev_environment`:

```bash
vault secrets enable -path=cyrene_dev_environment kv-v2
```

Verify:

```bash
vault secrets list
```

Expected:

```
cyrene_dev_environment/   kv-v2
```

---

## 2️⃣ Create a Secret (Example)

Create a secret named `environment`:

```bash
vault kv put cyrene_dev_environment/environment \
  NODE_ENV=dev \
  DB_HOST=localhost \
  DB_USER=admin
```

Read the secret:

```bash
vault kv get cyrene_dev_environment/environment
```

---

## 3️⃣ Enable CAS, Versioning & Retention (Per Secret)

⚠️ KV v2 metadata is **per key**, NOT global.

Apply metadata to the secret:

```bash
vault kv metadata put \
  -cas-required=true \
  -max-versions=2 \
  -delete-version-after=0s \
  cyrene_dev_environment/environment
```

Verify metadata:

```bash
vault kv metadata get cyrene_dev_environment/environment
```

Expected:

```
cas_required          true
max_versions          2
delete_version_after  0s
```

---

## 4️⃣ Update Secret with CAS (Required)

First update (CAS = version 1):

```bash
vault kv put -cas=1 cyrene_dev_environment/environment DB_USER=admin2
```

Update **without CAS** (will fail):

```bash
vault kv put cyrene_dev_environment/environment DB_USER=admin3
```

---

## 5️⃣ List Secrets (Always Do This First)

```bash
vault kv list cyrene_dev_environment/
```

Output example:

```
Keys
----
environment
```

> ⚠️ Vault paths are **string‑exact**. Typos create new secrets.

---

## 6️⃣ Delete a Secret (KV v2 – Correct Way)

### ❌ Soft delete (NOT enough)

Deletes only latest version data:

```bash
vault kv delete cyrene_dev_environment/environment
```

Secret will **still appear in UI**.

---

### ✅ Hard delete (REAL delete)

Deletes all versions + metadata:

```bash
vault kv metadata delete cyrene_dev_environment/environment
```

Verify:

```bash
vault kv list cyrene_dev_environment/
```

Expected:

```
No value found at cyrene_dev_environment/metadata
```

---

## 7️⃣ UI vs CLI (Very Important)

| Action            | CLI Result    | UI Behavior   |
| ----------------- | ------------- | ------------- |
| `kv delete`       | Data removed  | Still visible |
| `metadata delete` | Fully removed | May cache     |
| Logout / login    | —             | UI refresh    |

If UI still shows deleted secrets:

* Hard refresh (`Cmd + Shift + R`)
* Or logout/login

---

## 8️⃣ Delete Entire Secrets Engine (Optional)

⚠️ Deletes EVERYTHING under the mount.

```bash
vault secrets disable cyrene_dev_environment/
```

Verify:

```bash
vault secrets list
```

---

## Best Practices (Learned the Hard Way)

* Always `vault kv list` before delete
* Copy‑paste exact key names
* Never rely on UI alone
* Use naming conventions:

  ```text
  env/dev/app-name
  env/prod/app-name
  ```

---

## Summary

* KV v2 delete ≠ metadata delete
* Metadata delete = real deletion
* UI is eventually consistent
* CLI is always correct

This README reflects **real‑world Vault behavior**, not just docs.
