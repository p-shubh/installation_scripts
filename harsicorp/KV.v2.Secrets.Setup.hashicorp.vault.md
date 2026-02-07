# HashiCorp Vault – KV v2 Secrets Setup (cyrene_ai)

This guide explains how to configure **KV v2 secrets** in HashiCorp Vault under the `cyrene_ai` path, manage metadata, create secrets via CLI, list them, and delete them safely.

---

## Prerequisites

* Vault installed and running
* Vault initialized and unsealed
* Logged in with sufficient permissions

```bash
vault login
```

---

## Enable KV v2 Secrets Engine

Enable the KV v2 secrets engine at the path `cyrene_ai`:

```bash
vault secrets enable -path=cyrene_ai kv-v2
```

Verify enabled secrets engines:

```bash
vault secrets list
```

---

## Verify Vault Token

Check details of the currently authenticated token:

```bash
vault token lookup
```

---

## Configure KV Metadata

Set metadata rules for the `cyrene_ai` KV engine:

```bash
vault kv metadata put \
  -cas-required=true \
  -max-versions=5 \
  -delete-version-after=0s \
  cyrene_ai
```

### Metadata Settings Explained

* **cas-required** → Prevents accidental overwrites
* **max-versions** → Keeps last 5 versions
* **delete-version-after** → Versions never auto-delete

---

## Create Secrets Using CLI (Recommended)

### 🔹 Secret 1: Application Configuration

```bash
vault kv put cyrene_ai/development \
  APP_NAME=cyrene-ai \
  LOG_LEVEL=debug \
  PORT=8080
```

---

### 🔹 Secret 2: Environment-Based Secrets (Nested Paths)

#### Development Environment

```bash
vault kv put cyrene_ai/env/dev \
  API_URL=http://localhost:3000 \
  DEBUG=true
```

#### Production Environment

```bash
vault kv put cyrene_ai/env/prod \
  API_URL=https://api.cyrene.ai \
  DEBUG=false
```

---

## Retrieve a Secret

Fetch a secret value:

```bash
vault kv get cyrene_ai/app
```

---

## List Secrets

List all secrets under the `cyrene_ai` path:

```bash
vault kv list cyrene_ai/
```

---

## Delete Secrets (Correct Way)

### 🗑️ Delete Secret Data Only

(keeps metadata and version history)

```bash
vault kv delete cyrene_ai/database
```

### 🗑️ Delete Metadata Completely

(removes secret from UI and CLI list)

```bash
vault kv metadata delete cyrene_ai/database
```

---

## Best Practices

* Use **nested paths** for environments (`env/dev`, `env/prod`)
* Enable **CAS** to avoid accidental overwrites
* Delete **metadata** only when the secret is no longer needed
* Prefer **CLI over UI** for repeatable and auditable workflows

---

