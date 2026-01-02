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
  gh secret set "$key"     --env prod     --body "$value"     --repo ans-mishra/noah_whitelabel
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


# GitHub Repo Commands (gh CLI)

## Create a Private Repository with README
```bash
gh repo create <repo-name> --private --add-readme
````

✅ Correct way to add a collaborator using gh

Run this 👇

gh api \
  -X PUT \
  repos/ans-mishra/neurolov_whitelabel/collaborators/Abhishekk24 \
  -f permission=push

Permission options

pull → Read only

push → Read + Write

admin → Full access

🔐 Requirements (important)

You must be repo owner or have admin access

You must be logged in via:

gh auth status


If not logged in:

gh auth login

🔍 Verify collaborator added
gh api repos/ans-mishra/neurolov_whitelabel/collaborators


## Delete a Repository (Permanent)

⚠️ This action cannot be undone.

```bash
gh repo delete <owner>/<repo-name> --yes
```

## Requirements

* GitHub CLI installed
* Logged in via `gh auth login`

````

---

## ✅ Bash Script Version (Safe & Reusable)

### `github-repo.sh`

```bash
#!/bin/bash

ACTION=$1
REPO=$2

if [[ -z "$ACTION" || -z "$REPO" ]]; then
  echo "Usage:"
  echo "  Create repo : ./github-repo.sh create <repo-name>"
  echo "  Delete repo : ./github-repo.sh delete <owner>/<repo-name>"
  exit 1
fi

if [[ "$ACTION" == "create" ]]; then
  gh repo create "$REPO" --private --add-readme
  echo "✅ Repository created: $REPO"

elif [[ "$ACTION" == "delete" ]]; then
  echo "⚠️ Deleting repository: $REPO"
  gh repo delete "$REPO" --yes
  echo "🗑️ Repository deleted: $REPO"

else
  echo "❌ Invalid action. Use create or delete."
fi
````

### Make it executable

```bash
chmod +x github-repo.sh
```

### Usage

```bash
./github-repo.sh create my-private-repo
./github-repo.sh delete ans-mishra/testingPrivateRepsitoryCreation
```

---

Here’s the **GitHub CLI (`gh`) command** to **give a GitHub user access to a repository** 👇

---

## ✅ Give Access to a Repository (Add Collaborator)

```bash
gh repo add-collaborator <owner>/<repo-name> <github-username>
```

### Example

```bash
gh repo add-collaborator ans-mishra/testingPrivateRepsitoryCreation johndoe
```

This sends an **invitation** to the user.

---

## 🔐 Give Access with Specific Permission

```bash
gh repo add-collaborator <owner>/<repo-name> <github-username> --permission <level>
```

### Permission Levels

* `pull`  → Read-only
* `push`  → Write access
* `maintain` → Maintain (no destructive admin rights)
* `admin` → Full access

### Example

```bash
gh repo add-collaborator ans-mishra/testingPrivateRepsitoryCreation johndoe --permission push
```

---

## 📌 Notes

* The user must **accept the invite**
* You must have **admin rights** on the repo
* Works for **private and public** repositories

---

## 🔍 Check Collaborators

```bash
gh api repos/<owner>/<repo-name>/collaborators
```
