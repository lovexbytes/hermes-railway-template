FROM python:3.11-slim AS builder

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


FROM python:3.11-slim

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

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/hermes-agent /opt/hermes-agent

WORKDIR /app
COPY scripts/entrypoint.sh /app/scripts/entrypoint.sh
RUN chmod +x /app/scripts/entrypoint.sh
RUN rm -rf /root/.cache/* /tmp/*

ENTRYPOINT ["tini", "--"]
CMD ["/app/scripts/entrypoint.sh"]
