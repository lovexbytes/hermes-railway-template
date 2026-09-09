# Hermes Agent Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-railway-template?referralCode=uTN7AS&utm_medium=integration&utm_source=template&utm_campaign=generic)

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) to Railway as a worker service with persistent state. New deployments use the official Hermes Docker image; the previous Git source build remains available automatically for existing deployments that set `HERMES_GIT_REF`.

This template is worker-only: setup and configuration are done through Railway Variables, then the container bootstraps Hermes automatically on first run.

## What you get

- Hermes gateway running as a Railway worker
- First-boot bootstrap from environment variables
- Persistent Hermes state on a Railway volume at `/data`
- Telegram, Discord, or Slack support (at least one required)

## How it works

1. You configure required variables in Railway.
2. Railway uses the official `nousresearch/hermes-agent` image selected by `HERMES_IMAGE_VERSION`.
3. On first boot, entrypoint initializes Hermes under `/data/.hermes`.
4. On future boots, the same persisted state is reused.
5. Container starts `hermes gateway`.

## Railway deploy instructions

In Railway Template Composer:

1. Add a volume mounted at `/data`.
2. Deploy as a worker service.
3. Configure variables listed below.

Template defaults (declared in `.railway/railway.ts`):

- `HERMES_HOME=/data/.hermes`
- `HOME=/data`

Hermes terminal sessions default to `/data/workspace` via `${HERMES_HOME}/config.yaml`.

## Railway Infrastructure as Code

Railway configuration is defined with the supported TypeScript IaC format in
`.railway/railway.ts`; the deprecated `railway.toml` Config as Code file has
been removed.

After linking the repository to the intended Railway project and environment:

```bash
npm install
npm run railway:plan
npm run railway:apply
```

Always review the plan before applying it. Infrastructure as Code manages the
linked Railway environment, while the template's deployment button remains the
normal first-deploy path for end users.

## Default environment variables

This template defaults to Telegram + OpenRouter. These are the default variables to fill when deploying:

```env
HERMES_IMAGE_VERSION="latest"
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
  - OpenRouter: `OPENROUTER_API_KEY`
  - OpenAI / OpenAI-compatible endpoint: `OPENAI_API_KEY` and optionally `OPENAI_BASE_URL`
  - Anthropic: `ANTHROPIC_API_KEY` or `ANTHROPIC_TOKEN`
  - Google Gemini: `GOOGLE_API_KEY` or `GEMINI_API_KEY`
  - xAI: `XAI_API_KEY`
  - DeepSeek: `DEEPSEEK_API_KEY`
  - DashScope: `DASHSCOPE_API_KEY`
  - Kimi/Moonshot: `KIMI_API_KEY`
  - GLM/Z.AI: `GLM_API_KEY`
  - Hugging Face: `HF_TOKEN`
  - Vercel AI Gateway: `AI_GATEWAY_API_KEY`
  - MiniMax: `MINIMAX_API_KEY`
  - GitHub Copilot: `COPILOT_GITHUB_TOKEN`
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

## Optional environment variables

- `AGENT_CACHE_MEMORY_HIGH_MB=750` — sets Hermes' anonymous-RSS budget for cached session agents by writing the value to `agent.agent_cache.memory_high_mb` before startup. When omitted, the template leaves the existing Hermes configuration unchanged.
- `GATEWAY_ALLOW_ALL_USERS=true` — allows access without a user allowlist (not recommended).

Provider selection tip:

- If you set multiple provider keys, set `HERMES_INFERENCE_PROVIDER` (for example: `openrouter`, `openai`, `anthropic`, `gemini`, `xai`, `deepseek`, `kimi`, `glm`, or `dashscope`) to avoid auto-selection surprises.

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
- On Railway, update the default image-based deployment by changing `HERMES_IMAGE_VERSION`, then redeploy.
- `HERMES_IMAGE_VERSION` is appended only to the fixed official image repository `nousresearch/hermes-agent:`.

Recommended flow:

1. Set `HERMES_IMAGE_VERSION` to `latest`, `main`, or a published release tag such as `v2026.8.31`.
2. Deploy or redeploy the service.
3. If upstream introduced new config options, run `hermes config migrate` over Railway SSH after the redeploy.

For reproducible deployments, prefer a published release tag over the mutable `latest` or `main` tags.

## Deprecated source-build compatibility

`HERMES_GIT_REF` is deprecated but remains functional for backward compatibility. When it is present and non-empty, the Dockerfile automatically selects the previous source-build path instead of the official image path:

```env
HERMES_GIT_REF=v2026.8.31
```

The legacy path still supports release tags, branches, and arbitrary commit SHAs. Existing deployments with a non-empty `HERMES_GIT_REF` therefore keep their current build behavior without adding another mode variable or changing the Dockerfile path.

To migrate an existing deployment to the recommended official-image path:

1. Remove `HERMES_GIT_REF` or set it to an empty value.
2. Set `HERMES_IMAGE_VERSION` to `latest`, `main`, or a published release tag.
3. Redeploy.

The persistent Railway volume remains mounted at `/data`, and Hermes state remains under `/data/.hermes` in both modes. In official-image mode, the template keeps the upstream entrypoint and supervision stack, then applies a small stage-2 adapter that makes the Railway volume and `/data/workspace` writable by the image's unprivileged `hermes` runtime user.

### GitHub 429 warning for legacy builds

The legacy source-build path fetches `NousResearch/hermes-agent` from GitHub during every uncached Railway build. Railway build cache hits are not guaranteed, and GitHub may throttle concentrated CI traffic with HTTP `429 Too Many Requests`. Immediate redeploy retries can hit the same limit again.

This warning applies only to deployments with a non-empty `HERMES_GIT_REF`. The default official-image path does not clone the Hermes Git repository during the Railway build. If legacy builds repeatedly fail with GitHub 429 responses, remove `HERMES_GIT_REF`, select a published version through `HERMES_IMAGE_VERSION`, and redeploy.

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
- Writes runtime env to `${HERMES_HOME}/.env`
- Creates `${HERMES_HOME}/config.yaml` if missing
- Migrates deprecated `MESSAGING_CWD` from `${HERMES_HOME}/.env` into `config.yaml` and removes it from persisted env
- Maps `AGENT_CACHE_MEMORY_HIGH_MB` to Hermes' supported `agent.agent_cache.memory_high_mb` config setting
- Persists one-time marker `${HERMES_HOME}/.initialized`
- Starts `hermes gateway`

The Dockerfile chooses one complete build branch before runtime:

- empty or absent `HERMES_GIT_REF` → official `nousresearch/hermes-agent:${HERMES_IMAGE_VERSION}` image
- non-empty `HERMES_GIT_REF` → deprecated Python source build at that Git ref

Railway uses Docker BuildKit, so the unselected branch is not built.

## Troubleshooting

- `401 Missing Authentication header`: provider/key mismatch (often wrong provider auto-selection or missing API key for selected provider).
- Bot connected but no replies: check allowlist variables and user IDs.
- Data lost after redeploy: verify Railway volume is mounted at `/data`.

## Version selection

The two variables select different build sources and do not accept the same kinds of values:

- `HERMES_IMAGE_VERSION` selects a tag published for the fixed Docker image repository `nousresearch/hermes-agent`. Use `latest`, `main`, or an available release tag such as `v2026.8.31`. A Git branch name, commit SHA, or arbitrary Git ref works here only if upstream has also published a Docker image with that exact tag; otherwise the image pull fails.
- `HERMES_GIT_REF` selects source code directly from the `NousResearch/hermes-agent` Git repository. It accepts any ref GitHub can fetch, including a release tag, branch, or commit SHA. Because any non-empty value activates the deprecated source-build path, it takes precedence over `HERMES_IMAGE_VERSION`.

New deployments use the official image and default to:

```env
HERMES_IMAGE_VERSION=latest
```

Official-image examples:

```env
HERMES_IMAGE_VERSION=v2026.8.31
HERMES_IMAGE_VERSION=main
HERMES_IMAGE_VERSION=latest
```

Deprecated source-build examples:

```env
HERMES_GIT_REF=v2026.8.31
HERMES_GIT_REF=main
HERMES_GIT_REF=29112bef099274229cadff79cdff7bf7b99c4b77
```

## Local smoke test

```bash
# Recommended official-image path
docker build --build-arg HERMES_IMAGE_VERSION=v2026.8.31 -t hermes-railway-template .

# Deprecated source-build compatibility path
docker build --build-arg HERMES_GIT_REF=v2026.8.31 -t hermes-railway-template:legacy .

docker run --rm \
  -e OPENROUTER_API_KEY=sk-or-xxx \
  -e TELEGRAM_BOT_TOKEN=123456:ABC \
  -e TELEGRAM_ALLOWED_USERS=123456789 \
  -v "$(pwd)/.tmpdata:/data" \
  hermes-railway-template
```
