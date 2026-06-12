# Hermes Agent Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-railway-template?referralCode=uTN7AS&utm_medium=integration&utm_source=template&utm_campaign=generic)

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) to Railway as a worker service with persistent state.

This template is worker-only: setup and configuration are done through Railway Variables, then the container bootstraps Hermes automatically on first run.

## What you get

- Hermes gateway running as a Railway worker
- First-boot bootstrap from environment variables
- Persistent Hermes state on a Railway volume at `/data`
- Telegram, Discord, or Slack support (at least one required)

## How it works

1. You configure required variables in Railway.
2. On first boot, entrypoint initializes Hermes under `/data/.hermes`.
3. On future boots, the same persisted state is reused.
4. Container starts `hermes gateway`.

## Railway deploy instructions

In Railway Template Composer:

1. Add a volume mounted at `/data`.
2. Deploy as a worker service.
3. Configure variables listed below.

Template defaults (already included in `railway.toml`):

- `HERMES_HOME=/data/.hermes`
- `HOME=/data`

Hermes terminal sessions default to `/data/workspace` via `${HERMES_HOME}/config.yaml`.

## Default environment variables

This template defaults to Telegram + OpenRouter. These are the default variables to fill when deploying:

```env
HERMES_GIT_REF=""
OPENROUTER_API_KEY=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_ALLOWED_USERS=""
```

You can add or change variables later in Railway service Variables.
For the latest supported variables and behavior, follow upstream Hermes documentation:

- https://github.com/NousResearch/hermes-agent
- https://github.com/NousResearch/hermes-agent/blob/main/README.md

## Required runtime variables

You must set:

- At least one inference provider config:
  - `EVOLINK_API_KEY`, or
  - `OPENROUTER_API_KEY`, or
  - `OPENAI_BASE_URL` + `OPENAI_API_KEY`, or
  - `ANTHROPIC_API_KEY`
- At least one messaging platform:
  - Telegram: `TELEGRAM_BOT_TOKEN`
  - Discord: `DISCORD_BOT_TOKEN`
  - Slack: `SLACK_BOT_TOKEN` and `SLACK_APP_TOKEN`

Strongly recommended allowlists:

- `TELEGRAM_ALLOWED_USERS`
- `DISCORD_ALLOWED_USERS`
- `SLACK_ALLOWED_USERS`

Allowlist format examples (comma-separated, no brackets, no quotes):

- `TELEGRAM_ALLOWED_USERS=123456789,987654321`
- `DISCORD_ALLOWED_USERS=123456789012345678,234567890123456789`
- `SLACK_ALLOWED_USERS=U01234ABCDE,U09876WXYZ`

Use plain comma-separated values like `123,456,789`.
Do not use JSON or quoted arrays like `[123,456]` or `"123","456"`.

Optional global controls:

- `GATEWAY_ALLOW_ALL_USERS=true` (not recommended)

Provider selection tip:

- If you set multiple provider keys, set `HERMES_INFERENCE_PROVIDER` (for example: `openrouter`) to avoid auto-selection surprises.
- When `EVOLINK_API_KEY` is set, this template automatically maps it to Hermes' OpenAI-compatible provider settings:
  - `OPENAI_BASE_URL=https://direct.evolink.ai/v1`
  - `OPENAI_API_KEY=$EVOLINK_API_KEY`
  - `HERMES_INFERENCE_PROVIDER=openai`
  - `LLM_MODEL=gpt-5.2`

## Environment variable reference

For the full and up-to-date list, check out the [Hermes repository](https://github.com/NousResearch/hermes-agent).

## Simple usage guide

After deploy:

1. Start a chat with your bot on Telegram/Discord/Slack.
2. If using allowlists, ensure your user ID is included.
3. Send a normal message (for example: `hello`).
4. Hermes should respond via the configured model provider.

Helpful first checks:

- Confirm gateway logs show platform connection success.
- Confirm volume mount exists at `/data`.
- Confirm your provider variables are set and valid.

## Updating on Railway

Do not run `hermes update` inside a Railway deployment.

- `hermes update` mutates the live container and can leave persisted `/data/.hermes/config.yaml` ahead of the image that Railway boots on the next deploy.
- On Railway, update Hermes by changing `HERMES_GIT_REF` in service Variables to a pinned tag or commit, then redeploy.
- Railway exposes service variables at build time, and this template uses `ARG HERMES_GIT_REF` in the Dockerfile, so the build is pinned from that variable.

Recommended flow:

1. Set `HERMES_GIT_REF` to a specific upstream tag or commit SHA.
2. Deploy or redeploy the service.
3. If upstream introduced new config options, run `hermes config migrate` over Railway SSH after the redeploy.

## Running Hermes commands manually

If you want to run `hermes ...` commands manually inside the deployed service (for example `hermes config`, `hermes model`, or `hermes pairing list`), use [Railway SSH](https://docs.railway.com/cli/ssh) to connect to the running container.

Example commands after connecting:

```bash
hermes status
hermes config
hermes model
hermes pairing list
```

## Runtime behavior

Entrypoint (`scripts/entrypoint.sh`) does the following:

- Validates required provider and platform variables
- Maps `EVOLINK_API_KEY` to Hermes' OpenAI-compatible provider environment
- Writes runtime env to `${HERMES_HOME}/.env`
- Creates `${HERMES_HOME}/config.yaml` if missing
- Migrates deprecated `MESSAGING_CWD` from `${HERMES_HOME}/.env` into `config.yaml` and removes it from persisted env
- Persists one-time marker `${HERMES_HOME}/.initialized`
- Starts `hermes gateway`

## Troubleshooting

- `401 Missing Authentication header`: provider/key mismatch (often wrong provider auto-selection or missing API key for selected provider).
- Bot connected but no replies: check allowlist variables and user IDs.
- Data lost after redeploy: verify Railway volume is mounted at `/data`.

## Build pinning

This template requires `HERMES_GIT_REF` to be set explicitly.

Railway service variables are available at build time, and the Dockerfile reads:

- `ARG HERMES_GIT_REF`

Set `HERMES_GIT_REF` in Railway Variables to a pinned upstream tag or commit SHA.

Examples:

- `HERMES_GIT_REF=v2026.5.16`
- `HERMES_GIT_REF=4f3c2b1`

## Local smoke test

```bash
docker build --build-arg HERMES_GIT_REF=v2026.5.16 -t hermes-railway-template .

docker run --rm \
  -e OPENROUTER_API_KEY=sk-or-xxx \
  -e TELEGRAM_BOT_TOKEN=123456:ABC \
  -e TELEGRAM_ALLOWED_USERS=123456789 \
  -v "$(pwd)/.tmpdata:/data" \
  hermes-railway-template
```
