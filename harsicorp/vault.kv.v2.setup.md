# Vault KV v2 Setup with CAS & Versioning (CLI)

This README documents the **working and verified steps (STEP 1–4)** to create a **KV v2 secrets engine**, add a secret, and configure **CAS, versioning, and retention** using the **Vault CLI**.

This guide assumes you are already connected to Vault locally (for example, via SSH tunnel) and authenticated with a valid token.

---

## Prerequisites

* Vault CLI installed locally
* `VAULT_ADDR` set (example: `http://127.0.0.1:8200`)
* Logged in with a token that has permissions for:

  * `sys/mounts/*`
  * `cyrene_dev_environment/*`

Verify login:

```bash
vault status
```

---

## STEP 1: Enable KV v2 Secrets Engine

Create a KV v2 secrets engine at the desired path:

```bash
vault secrets enable -path=cyrene_dev_environment kv-v2
```

Verify the engine exists:

```bash
vault secrets list
```

Expected output includes:

```
cyrene_dev_environment/   kv-v2
```

---

## STEP 2: Create an Initial Secret Key

KV v2 **does not allow metadata operations on the mount root**.
You must create a key path first.

```bash
vault kv put cyrene_dev_environment/config init=true
```

This creates the logical key:

```
cyrene_dev_environment/config
```

---

## STEP 3: Apply Metadata Configuration (CAS, Versions, Retention)

Apply metadata **to the key path**, not the engine root:

```bash
vault kv metadata put \
  -cas-required=true \
  -max-versions=2 \
  -delete-version-after=0s \
  cyrene_dev_environment/config
```

### What this config does

| Setting                   | Effect                            |
| ------------------------- | --------------------------------- |
| `cas-required=true`       | Enforces Check-And-Set on updates |
| `max-versions=2`          | Keeps only the last 2 versions    |
| `delete-version-after=0s` | Never auto-delete versions        |

---

## STEP 4: Verify Metadata Configuration

```bash
vault kv metadata get cyrene_dev_environment/config
```

Expected output:

```
cas_required          true
max_versions          2
delete_version_after  0s
```

---

## Optional: Test CAS Enforcement

### First write (no CAS needed)

```bash
vault kv put cyrene_dev_environment/config key=value1
```

### Update with CAS (required)

```bash
vault kv put -cas=1 cyrene_dev_environment/config key=value2
```

### Update without CAS (should fail)

```bash
vault kv put cyrene_dev_environment/config key=value3
```

Expected: ❌ CAS validation error

---

## Important Notes

* KV v2 **metadata is per key**, not global
* UI configuration may look engine-wide, but Vault applies it per path
* Always apply metadata to a concrete secret path

---

## Summary

* ✅ KV v2 secrets engine created
* ✅ Secret key initialized
* ✅ CAS enforced
* ✅ Versioning limited to 2
* ✅ Retention set to never delete automatically

This setup matches the UI configuration and is fully reproducible via CLI.
