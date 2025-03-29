# syntax=docker/dockerfile:1.4

ARG STRIPE_CLI_VERSION=1.25.1

#######################################
# Stage 1: Runner Config Validator
#######################################
FROM stripe/stripe-cli:v${STRIPE_CLI_VERSION} AS runner-config-validator

RUN apk update \
 && apk add --no-cache \
      bash \
      curl \
      jq \
      openssl \
      ca-certificates;

ARG ENV
ARG COMPOSE_NETWORK_APP_URL
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN

# Validate build-args that we'll rely on at runtime
RUN test -n "${ENV}" || ( \
  echo "Error: ENV is not set! Use --build-arg ENV=xxx" && \
  exit 1 \
);
RUN test -n "${COMPOSE_NETWORK_APP_URL}" || ( \
  echo "Error: COMPOSE_NETWORK_APP_URL is not set! Use --build-arg COMPOSE_NETWORK_APP_URL=xxx" && \
  exit 1 \
);
RUN test -n "${HCP_ORG_ID}" || ( \
  echo "Error: HCP_ORG_ID is not set! Use --build-arg HCP_ORG_ID=xxx" && \
  exit 1 \
);
RUN test -n "${HCP_PROJECT_ID}" || ( \
  echo "Error: HCP_PROJECT_ID is not set! Use --build-arg HCP_PROJECT_ID=xxx" && \
  exit 1 \
);
RUN test -n "${HCP_ENCRYPTED_API_TOKEN}" || ( \
  echo "Error: HCP_ENCRYPTED_API_TOKEN is not set! Use --build-arg HCP_ENCRYPTED_API_TOKEN=xxx" && \
  exit 1 \
);

ENV ENV=${ENV}
ENV COMPOSE_NETWORK_APP_URL=${COMPOSE_NETWORK_APP_URL}
ENV HCP_ORG_ID=${HCP_ORG_ID}
ENV HCP_PROJECT_ID=${HCP_PROJECT_ID}
ENV HCP_ENCRYPTED_API_TOKEN=${HCP_ENCRYPTED_API_TOKEN}
ENV HCP_APP_NAME=shared-${ENV}

USER root
WORKDIR /root/

COPY devops-toolkit/backend/scripts/encryption.sh encryption.sh
COPY devops-toolkit/backend/scripts/fetch_hcp_secret.sh fetch_hcp_secret.sh

RUN chmod +x encryption.sh fetch_hcp_secret.sh;

#######################################
# Stage 2: Stripe Webhook Check Runner
#######################################
FROM runner-config-validator AS stripe-webhook-check-runner

ARG STRIPE_WEBHOOK_CHECK_ROUTE
ARG APP_NAME
ARG UNIQUE_RUN_NUMBER
ARG UNIQUE_RUNNER_ID

ENV STRIPE_WEBHOOK_CHECK_ROUTE=${STRIPE_WEBHOOK_CHECK_ROUTE}
ENV APP_NAME=${APP_NAME}
ENV UNIQUE_RUN_NUMBER=${UNIQUE_RUN_NUMBER}
ENV UNIQUE_RUNNER_ID=${UNIQUE_RUNNER_ID}

RUN test -n "${STRIPE_WEBHOOK_CHECK_ROUTE}" || ( \
  echo "Error: STRIPE_WEBHOOK_CHECK_ROUTE is not set! Use --build-arg STRIPE_WEBHOOK_CHECK_ROUTE=xxx" && \
  exit 1 \
);
RUN test -n "${APP_NAME}" || ( \
  echo "Error: APP_NAME is not set! Use --build-arg APP_NAME=xxx" && \
  exit 1 \
);
RUN test -n "${UNIQUE_RUN_NUMBER}" || ( \
  echo "Error: UNIQUE_RUN_NUMBER is not set! Use --build-arg UNIQUE_RUN_NUMBER=xxx" && \
  exit 1 \
);
RUN test -n "${UNIQUE_RUNNER_ID}" || ( \
  echo "Error: UNIQUE_RUNNER_ID is not set! Use --build-arg UNIQUE_RUNNER_ID=xxx" && \
  exit 1 \
);

COPY devops-toolkit/backend/scripts/health_check.sh health_check.sh
COPY devops-toolkit/backend/docker/scripts/stripe_webhook_check_runner_entrypoint.sh stripe_webhook_check_runner_entrypoint.sh
  
RUN chmod +x health_check.sh stripe_webhook_check_runner_entrypoint.sh;
  
ENTRYPOINT ./stripe_webhook_check_runner_entrypoint.sh; 
   
#######################################
# Stage 3: Stripe Listener Runner
#######################################
FROM runner-config-validator AS stripe-listener-runner

ARG STRIPE_WEBHOOK_EVENTS
ARG STRIPE_WEBHOOK_ROUTE

RUN test -n "${STRIPE_WEBHOOK_EVENTS}" || ( \
  echo "Error: STRIPE_WEBHOOK_EVENTS is not set! Use --build-arg STRIPE_WEBHOOK_EVENTS=xxx" && \
  exit 1 \
);
RUN test -n "${STRIPE_WEBHOOK_ROUTE}" || ( \
  echo "Error: STRIPE_WEBHOOK_ROUTE is not set! Use --build-arg STRIPE_WEBHOOK_ROUTE=xxx" && \
  exit 1 \
);

ENV STRIPE_WEBHOOK_EVENTS="${STRIPE_WEBHOOK_EVENTS}"
ENV STRIPE_WEBHOOK_ROUTE=${STRIPE_WEBHOOK_ROUTE}

COPY devops-toolkit/backend/docker/scripts/stripe_listener_runner_entrypoint.sh stripe_listener_runner_entrypoint.sh

RUN chmod +x stripe_listener_runner_entrypoint.sh;

ENTRYPOINT ./stripe_listener_runner_entrypoint.sh
