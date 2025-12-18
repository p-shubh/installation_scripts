# GitHub Environment Secrets Guide

## 1. Using GitHub CLI (`gh`) — Easiest

### Install GitHub CLI

```bash
brew install gh          # macOS
sudo apt install gh      # Ubuntu
```

### Login with your GitHub token

```bash
gh auth login
```

---

## Bulk Upload All Environment Secrets at Once

### Create a file named `prod.env`:

```
API_BASE_URL=https://api.example.com
JWT_SECRET=abc123
MONGO_URI=mongodb://localhost:27017
REDIS_PASS=xyz
```

### Upload all secrets to environment `prod`:

```bash
while IFS='=' read -r key value; do
  gh secret set "$key"     --env prod     --body "$value"     --repo ans-mishra/mikayla_whitelabel
done < prod.env
```

### Example

If `prod.env` contains:

```
API_BASE_URL=https://myapi.com
TOKEN=super-secret
```

Running the script uploads:

- `API_BASE_URL`
- `TOKEN`

---

## 2. Delete ALL secrets from an environment

### Delete all secrets from `prod`:

```bash
for secret in $(gh secret list --env prod --repo ans-mishra/evrey-whitelabel --json name -q '.[].name'); do
  gh secret delete "$secret" --env prod --repo ans-mishra/evrey-whitelabel
done
```

This deletes every secret inside the `prod` environment.

---


