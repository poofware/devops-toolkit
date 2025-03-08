FROM alpine:latest

##
# Install Dependencies & Migrate CLI
##
RUN apk add --no-cache ca-certificates bash postgresql-client curl jq \
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

##
# Transfer Build Args to Environment Variables
##
ENV MIGRATIONS_PATH=${MIGRATIONS_PATH}
ENV APP_NAME=${APP_NAME}
ENV ENV=${ENV}
ENV HCP_ORG_ID=${HCP_ORG_ID}
ENV HCP_PROJECT_ID=${HCP_PROJECT_ID}

##
# Hard-code Secret Name
##
ENV DATABASE_URL_SECRET_NAME=DB_URL

##
# Copy Migrations into Image
##
WORKDIR /app
COPY ${MIGRATIONS_PATH} migrations

##
# Final Command: Fetch DB URL from HCP & Run Migrations
##
CMD set -e ; \
    if [ ! -s /run/secrets/hcp_api_token ]; then \
      echo "[ERROR]: No HCP_API_TOKEN secret found in /run/secrets/hcp_api_token." >&2 ; \
      exit 1 ; \
    fi ; \
    export HCP_API_TOKEN="$(cat /run/secrets/hcp_api_token)" ; \
    echo "[INFO] [Migrate Container] Using HCP_API_TOKEN from secret mount..." ; \
    HCP_APP_NAME="${APP_NAME}-${ENV}" ; \
    echo "[INFO] [Migrate Container] Fetching secret '${DATABASE_URL_SECRET_NAME}' for app '${HCP_APP_NAME}' from HCP..." ; \
    PAYLOAD="$(curl --silent --show-error --location \
      "https://api.cloud.hashicorp.com/secrets/2023-11-28/organizations/${HCP_ORG_ID}/projects/${HCP_PROJECT_ID}/apps/${HCP_APP_NAME}/secrets/${DATABASE_URL_SECRET_NAME}:open" \
      --header "Authorization: Bearer ${HCP_API_TOKEN}")" ; \
    if [ $? -ne 0 ]; then \
      echo "[ERROR]: Failed to make request to HCP." >&2 ; \
      echo "Full response from HCP was:" >&2 ; \
      echo "$PAYLOAD" >&2 ; \
      exit 1 ; \
    fi ; \
    DB_URL="$(echo "$PAYLOAD" | jq -r '.secret.static_version.value // empty')" ; \
    if [ -z "$DB_URL" ]; then \
      echo "[ERROR]: Could not retrieve the secret '${DATABASE_URL_SECRET_NAME}' for app '${HCP_APP_NAME}'." >&2 ; \
      echo "Full response from HCP was:" >&2 ; \
      echo "$PAYLOAD" >&2 ; \
      exit 1 ; \
    fi ; \
    echo "[INFO] [Migrate Container] Checking database readiness..." ; \
    n=10 ; \
    while ! pg_isready -d "$DB_URL" -t 1 >/dev/null 2>&1 && [ $((n--)) -gt 0 ]; do \
      echo "  Waiting for DB to become ready..." ; \
      sleep 1 ; \
    done ; \
    if [ $n -le 0 ]; then \
      echo "[ERROR]: Failed to connect to DB after 10 attempts." >&2 ; \
      exit 1 ; \
    fi ; \
    echo "[INFO] [Migrate Container] Running migrations..." ; \
    migrate -path migrations -database "$DB_URL" up ;
