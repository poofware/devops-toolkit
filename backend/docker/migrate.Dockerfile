FROM alpine:latest AS migrate

##
# Install Dependencies & Migrate CLI
##
RUN apk add --no-cache ca-certificates bash postgresql-client curl jq openssl \
    && update-ca-certificates \
    && wget https://github.com/golang-migrate/migrate/releases/download/v4.16.2/migrate.linux-amd64.tar.gz \
    && tar xvf migrate.linux-amd64.tar.gz -C /usr/local/bin \
    && rm migrate.linux-amd64.tar.gz;

##
# Build-Time Arguments
##
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN
ARG HCP_APP_NAME_FOR_DB_SECRETS
ARG MIGRATIONS_PATH
ARG UNIQUE_RUN_NUMBER
ARG UNIQUE_RUNNER_ID

##
# Validate Required Build Args
##
RUN test -n "${HCP_ORG_ID}" || ( \
  echo "Error: HCP_ORG_ID is not set! Use --build-arg HCP_ORG_ID=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${HCP_PROJECT_ID}" || ( \
  echo "Error: HCP_PROJECT_ID is not set! Use --build-arg HCP_PROJECT_ID=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${HCP_ENCRYPTED_API_TOKEN}" || ( \
  echo "Error: HCP_ENCRYPTED_API_TOKEN is not set! Use --build-arg HCP_ENCRYPTED_API_TOKEN=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${HCP_APP_NAME_FOR_DB_SECRETS}" || ( \
  echo "Error: HCP_APP_NAME_FOR_DB_SECRETS is not set! Use --build-arg HCP_APP_NAME_FOR_DB_SECRETS=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${MIGRATIONS_PATH}" || ( \
  echo "Error: MIGRATIONS_PATH is not set! Use --build-arg MIGRATIONS_PATH=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${UNIQUE_RUN_NUMBER}" || ( \
  echo "Error: UNIQUE_RUN_NUMBER is not set! Use --build-arg UNIQUE_RUN_NUMBER=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${UNIQUE_RUNNER_ID}" || ( \
  echo "Error: UNIQUE_RUNNER_ID is not set! Use --build-arg UNIQUE_RUNNER_ID=xxx" >&2 && \
  exit 1 \
);

##
# Transfer Build Args to Environment Variables
##
ENV HCP_ORG_ID=${HCP_ORG_ID}
ENV HCP_PROJECT_ID=${HCP_PROJECT_ID}
ENV HCP_APP_NAME=${HCP_APP_NAME_FOR_DB_SECRETS}
ENV HCP_ENCRYPTED_API_TOKEN=${HCP_ENCRYPTED_API_TOKEN}
ENV MIGRATIONS_PATH=${MIGRATIONS_PATH}
ENV UNIQUE_RUN_NUMBER=${UNIQUE_RUN_NUMBER}
ENV UNIQUE_RUNNER_ID=${UNIQUE_RUNNER_ID}

##
# Copy Migrations into Image
##
WORKDIR /app
COPY ${MIGRATIONS_PATH} migrations
COPY devops-toolkit/backend/scripts/encryption.sh encryption.sh
COPY devops-toolkit/backend/scripts/fetch_launchdarkly_flag.sh fetch_launchdarkly_flag.sh
COPY devops-toolkit/shared/scripts/fetch_hcp_secret.sh fetch_hcp_secret.sh
COPY devops-toolkit/shared/scripts/fetch_hcp_secret_from_secrets_json.sh fetch_hcp_secret_from_secrets_json.sh
COPY devops-toolkit/backend/docker/scripts/migrate_cmd.sh migrate_cmd.sh

RUN chmod +x *.sh;

##
# Final Command: Fetch DB URL from HCP & Run Migrations
##
CMD ./migrate_cmd.sh
