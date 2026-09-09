# syntax=docker/dockerfile:1

ARG HERMES_GIT_REF
ARG HERMES_IMAGE_VERSION=latest
ARG SELECTED_STAGE=${HERMES_GIT_REF:+legacy}


# deprecated
FROM python:3.11-slim AS legacy-builder

ARG HERMES_GIT_REF

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN test -n "${HERMES_GIT_REF}" \
  && git init /opt/hermes-agent \
  && git -C /opt/hermes-agent remote add origin https://github.com/NousResearch/hermes-agent.git \
  && git -C /opt/hermes-agent fetch --depth 1 origin "${HERMES_GIT_REF}" \
  && git -C /opt/hermes-agent checkout --detach FETCH_HEAD \
  && git -C /opt/hermes-agent submodule update --init --recursive --depth 1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

RUN pip install --no-cache-dir --upgrade pip setuptools wheel
RUN pip install --no-cache-dir websockets -e "/opt/hermes-agent[messaging,cron,cli,pty]"


FROM python:3.11-slim AS legacy

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gh \
    nodejs \
    npm \
    tini \
  && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:${PATH}" \
  PYTHONUNBUFFERED=1 \
  HERMES_HOME=/data/.hermes \
  HOME=/data

COPY --from=legacy-builder /opt/venv /opt/venv
COPY --from=legacy-builder /opt/hermes-agent /opt/hermes-agent

WORKDIR /app
COPY scripts/entrypoint.sh /app/scripts/entrypoint.sh
RUN chmod +x /app/scripts/entrypoint.sh

ENTRYPOINT ["tini", "--"]
CMD ["/app/scripts/entrypoint.sh"]


FROM nousresearch/hermes-agent:${HERMES_IMAGE_VERSION} AS official

ENV HERMES_HOME=/data/.hermes \
  HERMES_WRITE_SAFE_ROOT=/data \
  HERMES_LAZY_INSTALL_TARGET=/data/.hermes/lazy-packages \
  HOME=/data

WORKDIR /app
COPY --chmod=0755 scripts/entrypoint.sh /app/scripts/entrypoint.sh
RUN mv /opt/hermes/docker/stage2-hook.sh /opt/hermes/docker/stage2-hook-upstream.sh
COPY --chmod=0755 <<'EOF' /opt/hermes/docker/stage2-hook.sh
#!/bin/sh
set -eu

# Run the official image bootstrap first so UID/GID remapping and targeted
# HERMES_HOME ownership fixes remain upstream-controlled.
/opt/hermes/docker/stage2-hook-upstream.sh "$@"

# Railway mounts the persistent volume at /data, while the official image
# normally owns /opt/data. Make the dedicated Railway volume and workspace
# writable by the final (possibly remapped) hermes user before command dispatch.
mkdir -p /data/.hermes /data/workspace
chown hermes:hermes /data /data/.hermes /data/workspace
EOF

CMD ["/app/scripts/entrypoint.sh"]


FROM ${SELECTED_STAGE:-official} AS final
