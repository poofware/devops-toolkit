# syntax=docker/dockerfile:1.4

#######################################
# Stage 1: Base for building & testing
#######################################
FROM golang:1.23-alpine AS base

# Install any necessary packages (git, openssh, etc.)
RUN apk update && apk add --no-cache git openssh curl openssl;

# Private repos? Configure SSH known_hosts if needed
ENV GOPRIVATE=github.com/poofware/*
RUN git config --global url."git@github.com:".insteadOf "https://github.com/";

WORKDIR /app

RUN mkdir -p /root/.ssh && ssh-keyscan github.com >> /root/.ssh/known_hosts;

# Copy mod files first
COPY go.mod go.sum ./

# Use BuildKit SSH mount to fetch private modules
RUN --mount=type=ssh go mod download;

#######################################
# Stage 2: Configuration Validation
#######################################
FROM base AS config-validator

ARG APP_NAME
ARG APP_PORT
ARG ENV
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN

# Validate the configuration
RUN test -n "${APP_NAME}" || ( \
  echo "Error: APP_NAME is not set! Use --build-arg APP_NAME=xxx" && \
  exit 1 \
);
RUN test -n "${APP_PORT}" || ( \
  echo "Error: APP_PORT is not set! Use --build-arg APP_PORT=xxx" && \
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

#######################################
# Stage 3: App Build Runner (compile app)
#######################################
FROM config-validator AS app-builder

ARG APP_NAME
ARG APP_PORT
ARG ENV
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN

# Copy the entire source for building
COPY internal/ ./internal/
COPY cmd/ ./cmd/

# Compile the app binary
# Transform ENV by replacing dashes (-) with underscores (_) to ensure valid Go 1.23 build tags
RUN go build \
      -ldflags "\
        -X 'github.com/poofware/${APP_NAME}/internal/config.AppPort=${APP_PORT}' \
        -X 'github.com/poofware/${APP_NAME}/internal/config.AppName=${APP_NAME}' \
        -X 'github.com/poofware/${APP_NAME}/internal/config.Env=${ENV}' \
        -X 'github.com/poofware/go-utils.HCPOrgID=${HCP_ORG_ID}' \
        -X 'github.com/poofware/go-utils.HCPProjectID=${HCP_PROJECT_ID}' \
        -X 'github.com/poofware/go-utils.HCPEncryptedAPIToken=${HCP_ENCRYPTED_API_TOKEN}'" \
      -v -o "/${APP_NAME}" ./cmd/main.go;

#######################################
# Stage 4: Integration Test Builder 
#######################################
FROM config-validator AS integration-test-builder

ARG ENV
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN

# Copy the files needed for building integration tests
COPY internal/ ./internal/

# Compile the integration test binary (from test/integration/)
# Transform ENV by replacing dashes (-) with underscores (_) to ensure valid Go 1.23 build tags,
# as dashes are not allowed in tag names per stricter parsing (alphanumeric and underscores only).
RUN set -euxo pipefail; \
    ENV_TRANSFORMED=$(echo "${ENV}" | tr '-' '_') && \
    go test -c -tags "${ENV_TRANSFORMED},integration" \
      -ldflags "\
        -X 'github.com/poofware/${APP_NAME}/internal/integration.Env=${ENV}' \
        -X 'github.com/poofware/go-utils.HCPOrgID=${HCP_ORG_ID}' \
        -X 'github.com/poofware/go-utils.HCPProjectID=${HCP_PROJECT_ID}' \
        -X 'github.com/poofware/go-utils.HCPEncryptedAPIToken=${HCP_ENCRYPTED_API_TOKEN}'" \
      -v -o /integration_test ./internal/integration/...;

#######################################
# Stage 5: Unit Test Builder 
#######################################
FROM base AS unit-test-builder

# Copy the test files for building
COPY internal/ ./internal/

# Compile the unit test binary (from internal/)
RUN go test -c -o /unit_test ./internal/...;

#######################################
# Stage 6: Integration Test Runner
#######################################
FROM alpine:latest AS integration-test-runner

ARG APP_NAME
ARG APP_PORT
ARG ENV

RUN apk add --no-cache curl;

WORKDIR /root/
COPY --from=integration-test-builder /integration_test ./integration_test

# Convert ARG to ENV for runtime use
ENV APP_NAME=${APP_NAME}
ENV SERVICE_URL="http://${APP_NAME}:${APP_PORT}"

ENTRYPOINT : ${SERVICE_URL:?Docker Entrypoint Error: SERVICE_URL not set! Check env files.}; \
    n=10; \
    while ! curl -sf "$SERVICE_URL/health" && [ $((n--)) -gt 0 ]; do \
      echo "Waiting for service health from $SERVICE_URL..."; \
      sleep 2; \
    done; \
    [ $n -le 0 ] && echo "Error: Failed to connect after 10 attempts." && exit 1; \
    exec "$0" "$@";

CMD ./integration_test -test.v;

#######################################
# Stage 7: Unit Test Runner
#######################################
FROM alpine:latest AS unit-test-runner

WORKDIR /root/
COPY --from=unit-test-builder /unit_test ./unit_test

CMD ./unit_test -test.v;

#######################################
# Stage 8: Minimal Final App Image
#######################################
FROM alpine:latest AS app

ARG APP_NAME
ARG APP_PORT

RUN apk add --no-cache curl;

WORKDIR /root/
COPY --from=app-builder /${APP_NAME} ./${APP_NAME}

EXPOSE ${APP_PORT}

# Convert ARG to ENV for runtime use with CMD
ENV APP_NAME=${APP_NAME}
ENV APP_PORT=${APP_PORT}

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:$APP_PORT/health || exit 1;

CMD ./$APP_NAME

