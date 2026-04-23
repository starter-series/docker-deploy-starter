# VPS Deployment Guide

Deploy your Docker container to any VPS (DigitalOcean, Hetzner, Vultr, Linode, AWS EC2, etc.) via SSH.

## 1. Prepare Your VPS

SSH into your server and install Docker:

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect
```

## 2. Create a Deploy User (recommended)

```bash
# On your VPS
sudo adduser deploy
sudo usermod -aG docker deploy
```

## 3. Set Up SSH Key

```bash
# On your local machine
ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""

# Copy public key to VPS
ssh-copy-id -i ~/.ssh/deploy_key.pub deploy@YOUR_VPS_IP
```

## 4. Add GitHub Secrets

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Value |
|--------|-------|
| `VPS_HOST` | Your server IP or domain (e.g. `203.0.113.10`) |
| `VPS_USER` | SSH username (e.g. `deploy`) |
| `VPS_SSH_KEY` | Contents of `~/.ssh/deploy_key` (the private key) |

## 5. Set Up Production Environment

On your VPS, create the environment file at `~/.env.app` — **this file must exist before the first deploy**. The CD workflow runs a preflight check and will fail with a clear message if it is missing.

```bash
# On your VPS
cat > ~/.env.app << 'EOF'
PORT=3000
# Add your production environment variables
EOF
chmod 600 ~/.env.app
```

The preflight also verifies `~/.env.app` is not world-readable. `chmod 600` is recommended; wider permissions trigger a warning but do not fail the deploy.

## 6. Deploy

**Option A: Manual trigger**
1. Bump version: `node scripts/bump-version.js patch`
2. Commit and push
3. Go to **Actions** tab → **Deploy** → **Run workflow**

**Option B: Tag push (automatic)**
1. Bump version: `node scripts/bump-version.js patch`
2. Commit, tag, and push:
   ```bash
   git add VERSION && git commit -m "Bump version"
   git tag v$(cat VERSION)
   git push && git push --tags
   ```

The workflow will:
1. Build your Docker image
2. Push to GitHub Container Registry
3. SSH into your VPS and create a `docker-compose.yml` at `~/app/`
4. Pull the new image and restart with health check verification (`docker compose up -d --wait`)
5. Clean up old images on VPS (`docker image prune`) and GHCR (keep last 10 versions)

## Troubleshooting

### Container won't start
```bash
# Check logs
cd ~/app
docker compose logs

# Check health status
docker compose ps

# Check if port is in use
sudo lsof -i :3000
```

### SSH connection fails
```bash
# Test SSH manually
ssh -i ~/.ssh/deploy_key deploy@YOUR_VPS_IP

# Check key permissions
chmod 600 ~/.ssh/deploy_key
```

### Image pull fails
```bash
# Login to GHCR on VPS
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

## Rollback

### Automatic Rollback

The CD workflow captures the currently running image before each deploy and reverts to it if the new version fails its health check.

- **Trigger:** `docker compose up -d --wait` fails (new container never reports healthy within the start period/retries).
- **What gets restored:** `~/app/docker-compose.yml` is rewritten back to the previous image tag and restarted in place — no manual SSH needed.
- **Signal:** the GHA job fails with `::error::Deploy health check failed.` and the rollback attempt is logged in the job output.
- **Constraint:** rollback only works if the previous image is still in the VPS's local Docker cache. `docker image prune` runs *only* on successful deploys, so the fallback image is preserved across a failure — but manual `docker image prune -a` or long-idle VPSs can evict it. If no previous image is available, the workflow logs `No previous image available to roll back to.` and exits non-zero.

### Manually Redeploying a Previous Version

If you need to roll back *after* a deploy that already succeeded (e.g. a bug slipped past the health check):

- **Re-run the last good GHA run:** Actions tab → pick the last green Deploy run → **Re-run all jobs**. Rebuilds and redeploys that commit's image.
- **Tag an earlier commit:** `git tag v1.2.3 <commit-sha> && git push --tags` triggers a fresh CD run against that commit.

### Quick Rollback (on VPS)

```bash
cd ~/app

# See available versions
docker images ghcr.io/YOUR_USER/YOUR_REPO

# Roll back to a specific version
sed -i 's/:.*/:1.0.2/' docker-compose.yml
docker compose pull
docker compose up -d --wait
```

### Rollback via GitHub Actions

Re-run the Deploy workflow with a previous version tag:

```bash
# On your local machine
git tag v1.0.2   # The version you want to roll back to
git push --tags  # This triggers the CD workflow with the old version
```

Or manually SSH and switch:

```bash
ssh deploy@YOUR_VPS_IP
cd ~/app
IMAGE="ghcr.io/YOUR_USER/YOUR_REPO:1.0.2"
sed -i "s|image:.*|image: $IMAGE|" docker-compose.yml
docker compose pull
docker compose up -d --wait
```

> **Tip:** GHCR keeps the last 10 versions by default (configured in `cd.yml`). Make sure the version you need hasn't been pruned.

## SSH Key Rotation

Rotate `VPS_SSH_KEY` on a quarterly cadence, or immediately if you suspect compromise (leaked laptop, ex-contributor access, etc.). The rotation is zero-downtime as long as you keep both keys valid during the switch.

1. **Generate a new ed25519 keypair** on your local machine (passphrase recommended for the at-rest copy):

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/deploy_key_new -C "deploy@$(date +%Y-%m)"
   ```

   See [OpenSSH docs](https://www.openssh.com/manual.html) for the underlying options.

2. **Append the new public key to the VPS** — do *not* remove the old one yet:

   ```bash
   ssh-copy-id -i ~/.ssh/deploy_key_new.pub deploy@YOUR_VPS_IP
   ```

3. **Update the GitHub Secret** `VPS_SSH_KEY` with the contents of the new *private* key (`~/.ssh/deploy_key_new`). Repo → Settings → Secrets and variables → Actions → `VPS_SSH_KEY` → Update.

4. **Verify CD still works.** Push a trivial commit (or re-run the last Deploy workflow) and confirm it reaches the VPS. If it fails, the old key is still authorized — roll back the secret and investigate.

5. **Remove the old public key** from `~/.ssh/authorized_keys` on the VPS once the new key is confirmed working:

   ```bash
   ssh deploy@YOUR_VPS_IP
   # Edit authorized_keys and delete the old line
   nano ~/.ssh/authorized_keys
   ```

6. **Delete the old private key locally** (`rm ~/.ssh/deploy_key`) and document the rotation date.

> **Locked out?** Use your VPS provider's web console (DigitalOcean, Hetzner, etc. all offer one) to log in, re-add a working public key, and restart. Never store the only copy of a recovery key in GitHub alone.

## Advanced: Multi-Container Setup

The default deployment creates a single-service `docker-compose.yml` on VPS at `~/app/`.
To add services (database, Redis, etc.), manually edit `~/app/docker-compose.yml` on your VPS:

```yaml
services:
  app:
    image: ghcr.io/your-user/your-repo:latest
    env_file: ~/.env.app
    ports:
      - "3000:3000"
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  pgdata:
```

> **Note:** The CD workflow overwrites `~/app/docker-compose.yml` on each deploy. For multi-container setups, update the SSH deploy script in `cd.yml` to preserve your additional services, or manage the compose file separately on the VPS.
