#!/usr/bin/env bash
set -euo pipefail

export HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
export HOME="${HOME:-/data}"
LEGACY_MESSAGING_CWD="${MESSAGING_CWD:-/data/workspace}"

INIT_MARKER="${HERMES_HOME}/.initialized"
ENV_FILE="${HERMES_HOME}/.env"
CONFIG_FILE="${HERMES_HOME}/config.yaml"
DEFAULT_TERMINAL_CWD="${TERMINAL_CWD:-${LEGACY_MESSAGING_CWD}}"

mkdir -p "${HERMES_HOME}" "${HERMES_HOME}/logs" "${HERMES_HOME}/sessions" "${HERMES_HOME}/cron" "${HERMES_HOME}/pairing" "${DEFAULT_TERMINAL_CWD}"

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

validate_platforms() {
  local count=0

  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    count=$((count + 1))
  fi

  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    count=$((count + 1))
  fi

  if [[ -n "${SLACK_BOT_TOKEN:-}" || -n "${SLACK_APP_TOKEN:-}" ]]; then
    if [[ -z "${SLACK_BOT_TOKEN:-}" || -z "${SLACK_APP_TOKEN:-}" ]]; then
      echo "[bootstrap] ERROR: Slack requires both SLACK_BOT_TOKEN and SLACK_APP_TOKEN." >&2
      exit 1
    fi
    count=$((count + 1))
  fi

  if [[ "$count" -lt 1 ]]; then
    echo "[bootstrap] ERROR: Configure at least one platform: Telegram, Discord, or Slack." >&2
    exit 1
  fi
}

has_valid_provider_config() {
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${OPENAI_BASE_URL:-}" && -n "${OPENAI_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" || -n "${ANTHROPIC_TOKEN:-}" ]]; then return 0; fi
  if [[ -n "${GOOGLE_API_KEY:-}" || -n "${GEMINI_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${XAI_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${DASHSCOPE_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${KIMI_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${GLM_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${HF_TOKEN:-}" ]]; then return 0; fi
  if [[ -n "${AI_GATEWAY_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${MINIMAX_API_KEY:-}" ]]; then return 0; fi
  if [[ -n "${COPILOT_GITHUB_TOKEN:-}" ]]; then return 0; fi

  return 1
}

append_if_set() {
  local key="$1"
  local val="${!key:-}"
  if [[ -n "$val" ]]; then
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
}

read_env_value() {
  local file="$1"
  local key="$2"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  grep -E "^${key}=" "$file" | head -n 1 | cut -d '=' -f 2-
}

config_has_terminal_cwd() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 1
  fi

  awk '
    /^terminal:[[:space:]]*$/ { in_terminal = 1; next }
    in_terminal && /^[^[:space:]]/ { in_terminal = 0 }
    in_terminal && /^[[:space:]]+cwd:[[:space:]]*/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$CONFIG_FILE"
}

config_has_terminal_section() {
  [[ -f "$CONFIG_FILE" ]] && grep -qE '^terminal:[[:space:]]*$' "$CONFIG_FILE"
}

create_default_config() {
  echo "[bootstrap] Creating ${CONFIG_FILE}"
  cat > "$CONFIG_FILE" <<EOF
terminal:
  backend: ${TERMINAL_ENV:-${TERMINAL_BACKEND:-local}}
  cwd: $1
  timeout: ${TERMINAL_TIMEOUT:-180}
compression:
  enabled: true
  threshold: 0.85
EOF
}

ensure_terminal_cwd_in_config() {
  local cwd="$1"
  local tmp_file

  if [[ ! -f "$CONFIG_FILE" ]]; then
    create_default_config "$cwd"
    return 0
  fi

  if config_has_terminal_cwd; then
    return 0
  fi

  if config_has_terminal_section; then
    tmp_file="$(mktemp)"
    awk -v cwd="$cwd" '
      /^terminal:[[:space:]]*$/ && !inserted {
        print
        print "  cwd: " cwd
        inserted = 1
        next
      }
      { print }
    ' "$CONFIG_FILE" > "$tmp_file"
    mv "$tmp_file" "$CONFIG_FILE"
    return 0
  fi

  printf '\nterminal:\n  cwd: %s\n' "$cwd" >> "$CONFIG_FILE"
}

migrate_legacy_messaging_cwd() {
  local persisted_cwd legacy_cwd

  persisted_cwd="$(read_env_value "$ENV_FILE" "MESSAGING_CWD" || true)"
  legacy_cwd="${persisted_cwd:-${MESSAGING_CWD:-}}"

  if [[ -n "$legacy_cwd" ]]; then
    ensure_terminal_cwd_in_config "$legacy_cwd"
  elif [[ ! -f "$CONFIG_FILE" ]]; then
    create_default_config "$DEFAULT_TERMINAL_CWD"
  fi
}

if ! has_valid_provider_config; then
  echo "[bootstrap] ERROR: Configure a provider: OPENROUTER_API_KEY, or OPENAI_BASE_URL+OPENAI_API_KEY, or ANTHROPIC_API_KEY." >&2
  exit 1
fi

validate_platforms

migrate_legacy_messaging_cwd

echo "[bootstrap] Writing runtime env to ${ENV_FILE}"
{
  echo "# Managed by entrypoint.sh"
  echo "HERMES_HOME=${HERMES_HOME}"
} > "$ENV_FILE"

for key in \
  OPENROUTER_API_KEY OPENAI_API_KEY OPENAI_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_TOKEN GOOGLE_API_KEY GEMINI_API_KEY XAI_API_KEY DEEPSEEK_API_KEY DASHSCOPE_API_KEY KIMI_API_KEY GLM_API_KEY HF_TOKEN AI_GATEWAY_API_KEY MINIMAX_API_KEY COPILOT_GITHUB_TOKEN LLM_MODEL HERMES_INFERENCE_PROVIDER HERMES_PORTAL_BASE_URL NOUS_INFERENCE_BASE_URL HERMES_NOUS_MIN_KEY_TTL_SECONDS HERMES_DUMP_REQUESTS \
  TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS TELEGRAM_ALLOW_ALL_USERS TELEGRAM_HOME_CHANNEL TELEGRAM_HOME_CHANNEL_NAME TELEGRAM_PROXY \
  DISCORD_BOT_TOKEN DISCORD_ALLOWED_USERS DISCORD_ALLOW_ALL_USERS DISCORD_HOME_CHANNEL DISCORD_HOME_CHANNEL_NAME DISCORD_REQUIRE_MENTION DISCORD_FREE_RESPONSE_CHANNELS DISCORD_REPLY_TO_MODE \
  SLACK_BOT_TOKEN SLACK_APP_TOKEN SLACK_ALLOWED_USERS SLACK_ALLOW_ALL_USERS SLACK_HOME_CHANNEL SLACK_HOME_CHANNEL_NAME WHATSAPP_ENABLED WHATSAPP_ALLOWED_USERS \
  GATEWAY_ALLOW_ALL_USERS API_SERVER_ENABLED API_SERVER_KEY API_SERVER_PORT API_SERVER_HOST API_SERVER_MODEL_NAME \
  FIRECRAWL_API_KEY NOUS_API_KEY BROWSERBASE_API_KEY BROWSERBASE_PROJECT_ID BROWSERBASE_PROXIES BROWSERBASE_ADVANCED_STEALTH BROWSER_SESSION_TIMEOUT BROWSER_INACTIVITY_TIMEOUT FAL_KEY ELEVENLABS_API_KEY VOICE_TOOLS_OPENAI_KEY \
  TINKER_API_KEY WANDB_API_KEY RL_API_URL GITHUB_TOKEN \
  TERMINAL_ENV TERMINAL_BACKEND TERMINAL_DOCKER_IMAGE TERMINAL_SINGULARITY_IMAGE TERMINAL_MODAL_IMAGE TERMINAL_CWD TERMINAL_TIMEOUT TERMINAL_LIFETIME_SECONDS TERMINAL_CONTAINER_CPU TERMINAL_CONTAINER_MEMORY TERMINAL_CONTAINER_DISK TERMINAL_CONTAINER_PERSISTENT TERMINAL_SANDBOX_DIR TERMINAL_SSH_HOST TERMINAL_SSH_USER TERMINAL_SSH_PORT TERMINAL_SSH_KEY SUDO_PASSWORD \
  WEB_TOOLS_DEBUG VISION_TOOLS_DEBUG MOA_TOOLS_DEBUG IMAGE_TOOLS_DEBUG CONTEXT_COMPRESSION_ENABLED CONTEXT_COMPRESSION_THRESHOLD CONTEXT_COMPRESSION_MODEL HERMES_MAX_ITERATIONS HERMES_TOOL_PROGRESS HERMES_TOOL_PROGRESS_MODE
do
  append_if_set "$key"
done

if [[ ! -f "$INIT_MARKER" ]]; then
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$INIT_MARKER"
  echo "[bootstrap] First-time initialization completed."
else
  echo "[bootstrap] Existing Hermes data found. Skipping one-time init."
fi

if [[ -z "${TELEGRAM_ALLOWED_USERS:-}${DISCORD_ALLOWED_USERS:-}${SLACK_ALLOWED_USERS:-}" ]]; then
  if ! is_true "${GATEWAY_ALLOW_ALL_USERS:-}" && ! is_true "${TELEGRAM_ALLOW_ALL_USERS:-}" && ! is_true "${DISCORD_ALLOW_ALL_USERS:-}" && ! is_true "${SLACK_ALLOW_ALL_USERS:-}"; then
    echo "[bootstrap] WARNING: No allowlists configured. Gateway defaults to deny-all; use DM pairing or set *_ALLOWED_USERS." >&2
  fi
fi

echo "[bootstrap] Starting Hermes gateway..."
unset MESSAGING_CWD
exec hermes gateway
