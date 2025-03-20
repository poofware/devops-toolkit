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
ARG MIGRATIONS_PATH
ARG APP_NAME
ARG ENV
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN

##
# Validate Required Build Args
##
RUN test -n "${MIGRATIONS_PATH}" || ( \
  echo "Error: MIGRATIONS_PATH is not set! Use --build-arg MIGRATIONS_PATH=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${APP_NAME}" || ( \
  echo "Error: APP_NAME is not set! Use --build-arg APP_NAME=xxx" >&2 && \
  exit 1 \
);
RUN test -n "${ENV}" || ( \
  echo "Error: ENV is not set! Use --build-arg ENV=xxx" >&2 && \
  exit 1 \
);
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

##
# Transfer Build Args to Environment Variables
##
ENV MIGRATIONS_PATH=${MIGRATIONS_PATH}
ENV HCP_ORG_ID=${HCP_ORG_ID}
ENV HCP_PROJECT_ID=${HCP_PROJECT_ID}
ENV HCP_APP_NAME=${APP_NAME}-${ENV}
ENV HCP_ENCRYPTED_API_TOKEN=${HCP_ENCRYPTED_API_TOKEN}

##
# Copy Migrations into Image
##
WORKDIR /app
COPY ${MIGRATIONS_PATH} migrations
COPY devops-toolkit/backend/scripts/encryption.sh encryption.sh
COPY devops-toolkit/backend/scripts/fetch_hcp_secret.sh fetch_hcp_secret.sh
COPY devops-toolkit/backend/docker/scripts/migrate_cmd.sh migrate_cmd.sh

RUN chmod +x encryption.sh fetch_hcp_secret.sh migrate_cmd.sh;

##
# Final Command: Fetch DB URL from HCP & Run Migrations
##
CMD ./migrate_cmd.sh
