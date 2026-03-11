# HTTPS Setup Guide

Set up automatic HTTPS on your VPS with Caddy reverse proxy.

## Why Caddy?

- **Auto TLS** — Automatically obtains and renews Let's Encrypt certificates
- **Zero config** — No manual cert management, no cron jobs
- **One binary** — No dependencies, ~40MB
- Works perfectly alongside Docker

## 1. Install Caddy on VPS

```bash
# Ubuntu/Debian
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudflare.com/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudflare.com/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

## 2. Point Your Domain

Add an **A record** pointing your domain to your VPS IP:

```
Type: A
Name: yourdomain.com (or subdomain)
Value: YOUR_VPS_IP
TTL: 300
```

> **Important:** DNS must be propagated before Caddy can obtain certificates. Verify with `dig yourdomain.com`.

## 3. Configure Caddy

Create `/etc/caddy/Caddyfile`:

```
yourdomain.com {
    reverse_proxy localhost:3000
}
```

That's it. Caddy automatically:
- Obtains a Let's Encrypt certificate
- Redirects HTTP → HTTPS
- Renews certificates before expiry

### With Multiple Services

```
app.yourdomain.com {
    reverse_proxy localhost:3000
}

api.yourdomain.com {
    reverse_proxy localhost:8080
}
```

## 4. Start Caddy

```bash
# Start and enable on boot
sudo systemctl enable --now caddy

# Check status
sudo systemctl status caddy

# View logs
sudo journalctl -u caddy -f
```

## 5. Update Firewall

```bash
# Allow HTTP and HTTPS (required for cert validation)
sudo ufw allow 80
sudo ufw allow 443
```

## 6. Update Your App

Your app should listen on `localhost:3000` (internal only). Caddy handles the public-facing HTTPS.

In `~/.env.app` on VPS:

```
PORT=3000
# No need to configure TLS in your app
```

> **Do NOT** expose port 3000 publicly. Only Caddy's ports 80/443 should be open.

## Alternative: Caddy in Docker

If you prefer running Caddy as a Docker container alongside your app, add it to your VPS docker-compose:

```yaml
services:
  app:
    image: ghcr.io/your-user/your-repo:latest
    env_file: ~/.env.app
    expose:
      - "3000"  # Internal only, not published to host
    restart: unless-stopped

  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
```

Create `~/app/Caddyfile` on VPS:

```
yourdomain.com {
    reverse_proxy app:3000
}
```

> **Note:** When using Docker Caddy, change the CD workflow's SSH script to preserve the Caddyfile and only update the app image. See the [Multi-Container section](VPS_DEPLOY.md#advanced-multi-container-setup) in VPS_DEPLOY.md.

## Troubleshooting

### Certificate not issued
```bash
# Check Caddy logs
sudo journalctl -u caddy --no-pager -n 50

# Common causes:
# - DNS not pointing to this server
# - Ports 80/443 blocked by firewall
# - Another service using port 80 (nginx, apache)
```

### Check certificate status
```bash
# If Caddy installed as binary
curl -v https://yourdomain.com 2>&1 | grep "SSL certificate"

# Or check with openssl
echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Port conflict
```bash
# Check what's using port 80
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting service
sudo systemctl stop nginx  # or apache2
sudo systemctl disable nginx
```
