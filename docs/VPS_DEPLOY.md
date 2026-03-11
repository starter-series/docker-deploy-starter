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

1. Bump version: `./scripts/bump-version.sh patch`
2. Commit and push
3. Go to **Actions** tab → **Deploy** → **Run workflow**

The workflow will:
1. Build your Docker image
2. Push to GitHub Container Registry
3. SSH into your VPS
4. Pull the new image
5. Stop the old container and start the new one

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs app

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

## Advanced: Docker Compose on VPS

For multi-container setups, replace the SSH deploy step in `cd.yml`:

```yaml
- name: Deploy to VPS via SSH
  uses: appleboy/ssh-action@v1
  with:
    host: ${{ secrets.VPS_HOST }}
    username: ${{ secrets.VPS_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    script: |
      cd ~/app
      docker compose pull
      docker compose up -d
```

And place a `docker-compose.prod.yml` on your VPS at `~/app/docker-compose.yml`.
