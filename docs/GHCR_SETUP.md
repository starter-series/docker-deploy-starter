# GitHub Container Registry (GHCR) Setup

The CD workflow pushes your Docker image to GHCR automatically. No extra secrets needed — it uses `GITHUB_TOKEN`.

## Verify Permissions

1. Go to your repo → **Settings** → **Actions** → **General**
2. Under **Workflow permissions**, select **Read and write permissions**
3. Click **Save**

> If your organization restricts this, ask an admin to enable it or use a Personal Access Token instead.

## Make Your Image Public (optional)

By default, GHCR images inherit the repository's visibility. To make it public:

1. Go to your GitHub profile → **Packages**
2. Find your package → **Package settings**
3. Under **Danger Zone**, click **Change visibility** → **Public**

This lets anyone `docker pull` without authentication.

## Pull Your Image

```bash
# Public image
docker pull ghcr.io/YOUR_USERNAME/YOUR_REPO:latest

# Private image (login first)
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
docker pull ghcr.io/YOUR_USERNAME/YOUR_REPO:latest
```

## Using a Personal Access Token (alternative)

If `GITHUB_TOKEN` doesn't have sufficient permissions:

1. Go to **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Generate a new token with `write:packages` and `read:packages` scopes
3. Add it as a repository secret named `CR_PAT`
4. Update `cd.yml` to use `${{ secrets.CR_PAT }}` instead of `${{ secrets.GITHUB_TOKEN }}`
