# Hermes Agent Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-railway-template?referralCode=uTN7AS&utm_medium=integration&utm_source=template&utm_campaign=generic)

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) to Railway as a worker service with persistent state under `/data`.

## Deploy

1. Click **Deploy on Railway**.
2. Configure an inference provider and at least one messaging platform in Railway Variables.
3. Add your user ID to the platform allowlist.
4. Deploy, then send your bot a message.

The template starts `hermes gateway`, stores Hermes state in `/data/.hermes`, and uses `/data/workspace` as the default terminal working directory.

## Environment variables

The default setup uses OpenRouter and Telegram:

```env
OPENROUTER_API_KEY=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_ALLOWED_USERS=""
```

Allowlist values are comma-separated IDs without brackets or quoted arrays:

```env
TELEGRAM_ALLOWED_USERS=123456789,987654321
```

You can use other inference providers and messaging platforms supported by Hermes. See the [official Hermes repository](https://github.com/NousResearch/hermes-agent) for the current configuration options and environment variables; this template does not duplicate the upstream reference.

Template-specific variables:

- `HERMES_IMAGE_VERSION` — Docker image tag from the fixed `nousresearch/hermes-agent` repository. Defaults to `latest`. Valid examples include `latest`, `main`, and published release tags such as `v2026.8.31`. A branch or commit SHA works only if upstream published a Docker image with that exact tag.
- `HERMES_GIT_REF` — deprecated source-build compatibility option. Any non-empty value takes precedence over `HERMES_IMAGE_VERSION` and may be a Git tag, branch, or commit SHA.
- `AGENT_CACHE_MEMORY_HIGH_MB` — optional positive integer mapped to `agent.agent_cache.memory_high_mb` before startup.

For reproducible deployments, use a published release tag rather than mutable `latest` or `main`:

```env
HERMES_IMAGE_VERSION=v2026.8.31
```

### Deprecated source-build compatibility

Existing deployments with `HERMES_GIT_REF` continue to build Hermes directly from that Git ref. To switch to the official image, remove or empty `HERMES_GIT_REF`, set `HERMES_IMAGE_VERSION`, and redeploy.

Legacy source builds fetch GitHub during uncached Railway builds and may fail with `429 Too Many Requests` when GitHub rate-limits build traffic. Retrying immediately may hit the same limit. Prefer the official-image path to avoid cloning Hermes during the build.

## Updating Hermes

Do not run `hermes update` inside the deployed container. Container changes do not survive a Railway redeploy and can leave persisted configuration ahead of the image version.

Instead:

1. Change `HERMES_IMAGE_VERSION` in Railway Variables.
2. Redeploy.
3. If required by the release, run `hermes config migrate` through Railway SSH.

## Railway SSH

Use Railway SSH to inspect Hermes or run commands manually:

```bash
hermes status
hermes config
hermes model
hermes pairing list
```

## Troubleshooting

- **Bot does not respond:** verify the platform token, allowlist, and gateway logs.
- **`401 Missing Authentication header`:** verify the selected inference provider and its API key.
- **State disappears after redeploy:** verify the Railway volume is mounted at `/data`.
- **Legacy build fails with GitHub 429:** remove `HERMES_GIT_REF` and use `HERMES_IMAGE_VERSION`.

## Railway Infrastructure as Code

Railway configuration lives in `.railway/railway.ts`. After linking this repository to the intended Railway project and environment:

```bash
npm install
npm run railway:plan
npm run railway:apply
```

Review the plan before applying it.

## Local build

```bash
# Official image

docker build \
  --build-arg HERMES_IMAGE_VERSION=v2026.8.31 \
  -t hermes-railway-template .

# Deprecated source build

docker build \
  --build-arg HERMES_GIT_REF=v2026.8.31 \
  -t hermes-railway-template:legacy .
```
