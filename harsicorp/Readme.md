# Vault CLI Access via SSH Tunnel (Local Setup)

This guide explains how to access **HashiCorp Vault** securely from your **local machine** using **Vault CLI** and **SSH port forwarding**, without going through Cloudflare or the public UI.

This setup uses **token-only authentication** and is suitable for admin and operational tasks.

---

## Prerequisites

* ✅ SSH access to the Vault server
* ✅ Vault running on the server (Docker in this case)
* ✅ A valid Vault token with required permissions
* ✅ macOS (steps shown for macOS)

Vault container example (server-side):

```
hashicorp/vault:1.20
0.0.0.0:8200 -> 8200
```

---

## Architecture (What’s Happening)

```
Local Machine (Vault CLI)
        │
        │ SSH Tunnel
        ▼
localhost:8200  ─────▶  Vault Server :8200
                          (Docker)
```

* Cloudflare is **completely bypassed**
* Vault validates the token **directly**

---

## Step 1: Install Vault CLI (Local)

Install Vault CLI using Homebrew:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/vault
```

Verify installation:

```bash
vault version
```

---

## Step 2: Create SSH Tunnel

From your **local machine**, run:

```bash
 ssh -N -L 8200:127.0.0.1:8200 root@139.84.153.127
```

Replace:

* `user` → SSH username
* `<VAULT_SERVER_IP>` → Vault server IP / hostname

📌 Keep this terminal **open** while using Vault.

---

## Step 3: Configure Vault Address (Local)

Open a **new terminal tab** and set:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
```

> Use `http` unless Vault is explicitly configured with TLS internally.

---

## Step 4: Login to Vault (Token Only)

Authenticate using your Vault token:

```bash
vault login <VAULT_TOKEN>
```

Expected output:

```
Success! You are now authenticated.
```

---

## Step 5: Run Vault Commands

### List secrets engines

```bash
vault secrets list
```

### Disable (delete) a secrets engine

```bash
vault secrets disable dev_cyrene_ai/
```

### Verify deletion

```bash
vault secrets list
```

---

## Required Vault Policy

Your token must have the following capabilities:

```hcl
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "sudo", "list"]
}
```

---

## Troubleshooting

### ❌ Connection refused

* SSH tunnel not running
* Port 8200 already in use

Check:

```bash
lsof -i :8200
```

---

### ❌ Permission denied

* Token does not have required policy

---

### ❌ Vault sealed or standby

Check on the server:

```bash
docker exec -it vault vault status
```

---

## Security Notes (Important)

* Avoid exposing Vault publicly on `0.0.0.0:8200`
* Prefer binding Vault to `127.0.0.1` or firewall the port
* Never commit Vault tokens

---

## Summary

* ✅ Vault CLI runs locally
* ✅ SSH tunnel provides secure access
* ✅ Token-only authentication
* ❌ No Cloudflare / UI dependency

This is the **recommended admin workflow** for Vault.
