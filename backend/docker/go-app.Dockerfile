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
# Stage 2: Builder Config Validator
#######################################
FROM base AS builder-config-validator

ARG APP_NAME
ARG APP_PORT
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG LD_SERVER_CONTEXT_KEY
ARG LD_SERVER_CONTEXT_KIND

# Validate the configuration
RUN test -n "${APP_NAME}" || ( \
  echo "Error: APP_NAME is not set! Use --build-arg APP_NAME=xxx" && \
  exit 1 \
);
RUN test -n "${APP_PORT}" || ( \
  echo "Error: APP_PORT is not set! Use --build-arg APP_PORT=xxx" && \
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
RUN test -n "${LD_SERVER_CONTEXT_KEY}" || ( \
  echo "Error: LD_SERVER_CONTEXT_KEY is not set! Use --build-arg LD_SERVER_CONTEXT_KEY=xxx" && \
  exit 1 \
);
RUN test -n "${LD_SERVER_CONTEXT_KIND}" || ( \
  echo "Error: LD_SERVER_CONTEXT_KIND is not set! Use --build-arg LD_SERVER_CONTEXT_KIND=xxx" && \
  exit 1 \
);

#######################################
# Stage 3: App Build Runner (compile app)
#######################################
FROM builder-config-validator AS app-builder

ARG APP_NAME
ARG APP_PORT
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG LD_SERVER_CONTEXT_KEY
ARG LD_SERVER_CONTEXT_KIND

# Copy the entire source for building
COPY internal/ ./internal/
COPY cmd/ ./cmd/

# Compile the app binary
# Transform ENV by replacing dashes (-) with underscores (_) to ensure valid Go 1.23 build tags
RUN go build \
      -ldflags "\
        -X 'github.com/poofware/${APP_NAME}/internal/config.AppPort=${APP_PORT}' \
        -X 'github.com/poofware/${APP_NAME}/internal/config.AppName=${APP_NAME}' \
        -X 'github.com/poofware/${APP_NAME}/internal/config.LDServerContextKey=${LD_SERVER_CONTEXT_KEY}' \
        -X 'github.com/poofware/${APP_NAME}/internal/config.LDServerContextKind=${LD_SERVER_CONTEXT_KIND}' \
        -X 'github.com/poofware/go-utils.HCPOrgID=${HCP_ORG_ID}' \
        -X 'github.com/poofware/go-utils.HCPProjectID=${HCP_PROJECT_ID}'" \
      -v -o "/${APP_NAME}" ./cmd/main.go;

#######################################
# Stage 4: Integration Test Builder 
#######################################
FROM builder-config-validator AS integration-test-builder

ARG APP_NAME
ARG ENV
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG LD_SERVER_CONTEXT_KEY
ARG LD_SERVER_CONTEXT_KIND

# Not in builder-config-validator stage, as this changes somewhat often, 
# and we don't want to invalidate the builder stage cache for other builders every time we change it
RUN test -n "${ENV}" || ( \
  echo "Error: ENV is not set! Use --build-arg ENV=xxx" && \
  exit 1 \
);

# Copy the files needed for building integration tests
COPY internal/ ./internal/

# Compile the integration test binary (from test/integration/)
# Transform ENV by replacing dashes (-) with underscores (_) to ensure valid Go 1.23 build tags,
# as dashes are not allowed in tag names per stricter parsing (alphanumeric and underscores only).
RUN set -euxo pipefail; \
    ENV_TRANSFORMED=$(echo "${ENV}" | tr '-' '_') && \
    go test -c -tags "${ENV_TRANSFORMED},integration" \
      -ldflags "\
        -X 'github.com/poofware/${APP_NAME}/internal/config.AppName=${APP_NAME}' \
        -X 'github.com/poofware/${APP_NAME}/internal/config.LDServerContextKey=${LD_SERVER_CONTEXT_KEY}' \
        -X 'github.com/poofware/${APP_NAME}/internal/config.LDServerContextKind=${LD_SERVER_CONTEXT_KIND}' \
        -X 'github.com/poofware/go-utils.HCPOrgID=${HCP_ORG_ID}' \
        -X 'github.com/poofware/go-utils.HCPProjectID=${HCP_PROJECT_ID}'" \
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
# Stage 6: Runner Config Validator
#######################################

FROM alpine:latest AS runner-config-validator

ARG ENV
ARG HCP_ENCRYPTED_API_TOKEN

# Run these validations here instead of the builder-config-validator stage, as these change often, and we don't want to invalidate
# the builder stage cache every time we change them
RUN test -n "${ENV}" || ( \
  echo "Error: ENV is not set! Use --build-arg ENV=xxx" && \
  exit 1 \
);
RUN test -n "${HCP_ENCRYPTED_API_TOKEN}" || ( \
  echo "Error: HCP_ENCRYPTED_API_TOKEN is not set! Use --build-arg HCP_ENCRYPTED_API_TOKEN=xxx" && \
  exit 1 \
);

#######################################
# Stage 7: Integration Test Runner
#######################################
FROM runner-config-validator AS integration-test-runner

ARG APP_NAME
ARG ENV
ARG APP_URL
ARG HCP_ORG_ID
ARG HCP_PROJECT_ID
ARG HCP_ENCRYPTED_API_TOKEN

RUN apk add --no-cache curl jq openssl bash ca-certificates && update-ca-certificates;

WORKDIR /root/
COPY --from=integration-test-builder /integration_test ./integration_test
COPY devops-toolkit/backend/scripts/encryption.sh encryption.sh
COPY devops-toolkit/backend/scripts/fetch_hcp_secret.sh fetch_hcp_secret.sh
COPY devops-toolkit/backend/scripts/fetch_ld_flag.sh fetch_ld_flag.sh
COPY devops-toolkit/backend/docker/scripts/integration_test_runner_cmd.sh integration_test_runner_cmd.sh

RUN chmod +x encryption.sh fetch_hcp_secret.sh fetch_ld_flag.sh integration_test_runner_cmd.sh;

# Convert ARG to ENV for runtime use
ENV ENV=${ENV}
ENV APP_URL=${APP_URL}
ENV HCP_ORG_ID=${HCP_ORG_ID}
ENV HCP_PROJECT_ID=${HCP_PROJECT_ID}
ENV HCP_APP_NAME=${APP_NAME}-${ENV}
ENV HCP_ENCRYPTED_API_TOKEN=${HCP_ENCRYPTED_API_TOKEN}

CMD ./integration_test_runner_cmd.sh;

#######################################
# Stage 8: Unit Test Runner
#######################################
FROM alpine:latest AS unit-test-runner

WORKDIR /root/
COPY --from=unit-test-builder /unit_test ./unit_test

CMD ./unit_test -test.v;

#######################################
# Stage 9: Minimal Final App Image
#######################################
FROM runner-config-validator AS app-runner

ARG APP_NAME
ARG APP_PORT
ARG ENV
ARG HCP_ENCRYPTED_API_TOKEN

RUN apk add --no-cache curl;

WORKDIR /root/
COPY --from=app-builder /${APP_NAME} ./${APP_NAME}

EXPOSE ${APP_PORT}

# Convert ARG to ENV for runtime use with CMD
ENV APP_NAME=${APP_NAME}
ENV APP_PORT=${APP_PORT}
ENV ENV=${ENV}
ENV HCP_ENCRYPTED_API_TOKEN=${HCP_ENCRYPTED_API_TOKEN}

# Copy all envs into a .env file for potential children images to access
RUN echo "APP_NAME=${APP_NAME}" > .env && \
    echo "APP_PORT=${APP_PORT}" >> .env && \
    echo "ENV=${ENV}" >> .env && \
    echo "HCP_ENCRYPTED_API_TOKEN=${HCP_ENCRYPTED_API_TOKEN}" >> .env;

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:$APP_PORT/health || exit 1;

CMD ./$APP_NAME

