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

On your VPS, create the environment file:

```bash
# On your VPS
cat > ~/.env.app << 'EOF'
PORT=3000
# Add your production environment variables
EOF
```

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

If a deployment breaks, roll back to a previous version using the GHCR version tags.

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
