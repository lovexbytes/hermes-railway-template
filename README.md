# Hermes Agent Railway Template (no web setup)

This template deploys [Nous Research Hermes Agent](https://github.com/NousResearch/hermes-agent) on Railway as a worker service, with no `/setup` web UI.

The deployment flow is:

1. You set required environment variables in Railway.
2. On first boot, the container bootstraps `HERMES_HOME` on the mounted volume.
3. On later boots, it reuses persisted state and starts `hermes gateway` immediately.

## Why this template

- No web setup UI (simpler and safer)
- Persistent Hermes state on Railway volume (`/data`)
- Explicit startup validation for required variables
- Works with Telegram, Discord, or Slack (at least one required)

## Required Railway Setup

In Railway Template Composer:

1) Add a volume mounted at `/data`.
2) Set environment variables (see below).
3) Deploy as a worker service.

## Required Variables

You must configure:

- At least one model provider key:
  - `OPENROUTER_API_KEY`, or
  - `OPENAI_API_KEY`, or
  - `ANTHROPIC_API_KEY`
- At least one messaging platform:
  - Telegram: `TELEGRAM_BOT_TOKEN`
  - Discord: `DISCORD_BOT_TOKEN`
  - Slack: `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN`

## Security Variables (strongly recommended)

Set allowlists for your chosen platform(s):

- `TELEGRAM_ALLOWED_USERS`
- `DISCORD_ALLOWED_USERS`
- `SLACK_ALLOWED_USERS`

Optional global overrides:

- `GATEWAY_ALLOWED_USERS`
- `GATEWAY_ALLOW_ALL_USERS=true` (not recommended)

If no allowlists are set and allow-all is false, gateway defaults to deny-all (you can still pair users via Hermes pairing flow).

## Included Defaults

`railway.toml` sets:

- `HERMES_HOME=/data/.hermes`
- `HOME=/data`
- `MESSAGING_CWD=/data/workspace`

This avoids split state paths and ensures persistence across redeploys.

## Runtime Behavior

Entrypoint script (`scripts/entrypoint.sh`) does the following:

- Validates required model/provider and platform vars
- Writes managed runtime env file: `${HERMES_HOME}/.env`
- Creates `${HERMES_HOME}/config.yaml` on first boot
- Writes one-time init marker: `${HERMES_HOME}/.initialized`
- Starts `hermes gateway`

## Build Pinning

Docker build arg:

- `HERMES_GIT_REF` (default: `main`)

Override it in Railway if you want to pin a specific tag/commit.

## Local Smoke Test

```bash
docker build -t hermes-railway-template .

docker run --rm \
  -e OPENROUTER_API_KEY=sk-or-xxx \
  -e TELEGRAM_BOT_TOKEN=123456:ABC \
  -e TELEGRAM_ALLOWED_USERS=123456789 \
  -v "$(pwd)/.tmpdata:/data" \
  hermes-railway-template
```

## Notes

- This template intentionally does not expose HTTP endpoints.
- Railway health checks should be process-based (worker lifecycle), not HTTP path based.
