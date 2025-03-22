# syntax=docker/dockerfile:1.4

#######################################
# Stage 1: Runner Config Validator
#######################################
FROM stripe/stripe-cli:latest AS runner-config-validator

RUN apk update \
 && apk add --no-cache \
      bash \
      curl \
      jq \
      openssl \
      ca-certificates;

ARG APP_URL
ARG ENV
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN
ARG STRIPE_WEBHOOK_ROUTE

# Validate build-args that we'll rely on at runtime
RUN test -n "${APP_URL}" || ( \
  echo "Error: APP_URL is not set! Use --build-arg APP_URL=xxx" && \
  exit 1 \
);
RUN test -n "${ENV}" || ( \
  echo "Error: ENV is not set! Use --build-arg ENV=xxx" && \
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
RUN test -n "${STRIPE_WEBHOOK_ROUTE}" || ( \
  echo "Error: STRIPE_WEBHOOK_ROUTE is not set! Use --build-arg STRIPE_WEBHOOK_ROUTE=xxx" && \
  exit 1 \
);

#######################################
# Stage 2: Stripe Listener Runner
#######################################
FROM runner-config-validator AS stripe-listener-runner

# Re-declare the same ARGs so the final stage can use them
ARG APP_URL
ARG ENV
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN
ARG STRIPE_WEBHOOK_ROUTE

# Set environment variables for runtime
ENV ENV=${ENV}
ENV HCP_ORG_ID=${HCP_ORG_ID}
ENV HCP_PROJECT_ID=${HCP_PROJECT_ID}
ENV HCP_ENCRYPTED_API_TOKEN=${HCP_ENCRYPTED_API_TOKEN}
ENV HCP_APP_NAME=shared-${ENV}
ENV FORWARD_TO_URL=${APP_URL}${STRIPE_WEBHOOK_ROUTE}

USER root
WORKDIR /root/

COPY devops-toolkit/backend/scripts/encryption.sh encryption.sh
COPY devops-toolkit/backend/scripts/fetch_hcp_secret.sh fetch_hcp_secret.sh
COPY devops-toolkit/backend/docker/scripts/stripe-listener-entrypoint.sh stripe-listener-entrypoint.sh

RUN chmod +x encryption.sh fetch_hcp_secret.sh stripe-listener-entrypoint.sh;

# Override the stripe default entrypoint
ENTRYPOINT ./stripe-listener-entrypoint.sh
