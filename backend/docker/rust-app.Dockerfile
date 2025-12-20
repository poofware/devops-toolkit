# syntax=docker/dockerfile:1.4

ARG RUST_VERSION=1.83

#######################################
# Stage 1: Base with cargo-chef
#######################################
FROM rust:${RUST_VERSION}-slim-bookworm AS base

# Tooling needed for cargo and TLS-enabled builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Pin cargo-chef to a version compatible with Rust 1.83 (avoids edition2024 deps)
RUN cargo install cargo-chef --version 0.1.67 --locked

WORKDIR /app

#######################################
# Stage 2: Planner (dependency graph)
#######################################
FROM base AS planner

COPY Cargo.toml Cargo.lock ./

# Create dummy source files so cargo-chef can analyze dependencies
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    echo "// dummy lib" > src/lib.rs

RUN cargo chef prepare --recipe-path recipe.json

#######################################
# Stage 3: App Builder (compile app)
#######################################
FROM base AS app-builder

ARG RUST_BUILD_PROFILE=release
ARG RUST_BINARY_NAME
ARG APP_NAME
ARG APP_PORT=8080
ARG APP_URL_FROM_ANYWHERE
ARG LOG_LEVEL=info
ARG ENV=dev

# Validate required args early
RUN test -n "${RUST_BINARY_NAME}" || ( \
  echo "Error: RUST_BINARY_NAME is not set! Use --build-arg RUST_BINARY_NAME=xxx" && \
  exit 1 \
);
RUN test -n "${APP_NAME}" || ( \
  echo "Error: APP_NAME is not set! Use --build-arg APP_NAME=xxx" && \
  exit 1 \
);
RUN test -n "${APP_URL_FROM_ANYWHERE}" || ( \
  echo "Error: APP_URL_FROM_ANYWHERE is not set! Use --build-arg APP_URL_FROM_ANYWHERE=xxx" && \
  exit 1 \
);

COPY Cargo.toml Cargo.lock ./
COPY --from=planner /app/recipe.json recipe.json

# Build dependency graph (cacheable when Cargo.toml/Cargo.lock unchanged)
# RUSTFLAGS: Set before chef cook so deps are compiled with same flags as app build
ENV RUSTFLAGS="-C target-cpu=native"
RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=rust-target,target=/app/target \
    cargo chef cook --${RUST_BUILD_PROFILE} --recipe-path recipe.json

# Copy ONLY source code - this layer only rebuilds when src/ changes
COPY src/ src/

# Build application with cached deps, then place binary at repo root
RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=rust-target,target=/app/target \
    cargo build --${RUST_BUILD_PROFILE} && \
    cp /app/target/${RUST_BUILD_PROFILE}/${RUST_BINARY_NAME} /${RUST_BINARY_NAME}

######################################
# Stage 4: Health Check Runner
######################################
FROM debian:bookworm-slim AS health-check-runner

ARG APP_URL_FROM_ANYWHERE

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    bash \
    && rm -rf /var/lib/apt/lists/*

RUN test -n "${APP_URL_FROM_ANYWHERE}" || ( \
  echo "Error: APP_URL_FROM_ANYWHERE is not set! Use --build-arg APP_URL_FROM_ANYWHERE=xxx" && \
  exit 1 \
);

ENV APP_URL_FROM_ANYWHERE=${APP_URL_FROM_ANYWHERE}

WORKDIR /root/
COPY --from=devops-toolkit backend/scripts/health_check.sh health_check.sh

CMD ./health_check.sh

#######################################
# Stage 5: Minimal Final App Image
#######################################
FROM debian:bookworm-slim AS app-runner

ARG APP_NAME
ARG APP_PORT=8080
ARG APP_URL_FROM_ANYWHERE
ARG LOG_LEVEL=info
ARG ENV=dev
ARG RUST_BINARY_NAME

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Validate runtime build args
RUN test -n "${RUST_BINARY_NAME}" || ( \
  echo "Error: RUST_BINARY_NAME is not set! Use --build-arg RUST_BINARY_NAME=xxx" && \
  exit 1 \
);
RUN test -n "${APP_NAME}" || ( \
  echo "Error: APP_NAME is not set! Use --build-arg APP_NAME=xxx" && \
  exit 1 \
);
RUN test -n "${APP_URL_FROM_ANYWHERE}" || ( \
  echo "Error: APP_URL_FROM_ANYWHERE is not set! Use --build-arg APP_URL_FROM_ANYWHERE=xxx" && \
  exit 1 \
);

WORKDIR /app

# Copy the built binary from the builder stage
COPY --from=app-builder /${RUST_BINARY_NAME} /app/${RUST_BINARY_NAME}

EXPOSE ${APP_PORT}

# Convert ARGs to ENV for runtime use (mirrors Go app pattern)
ENV APP_NAME=${APP_NAME}
ENV APP_PORT=${APP_PORT}
ENV APP_URL_FROM_ANYWHERE=${APP_URL_FROM_ANYWHERE}
ENV LOG_LEVEL=${LOG_LEVEL}
ENV ENV=${ENV}
ENV PORT=${APP_PORT}
ENV RUST_BINARY_NAME=${RUST_BINARY_NAME}

# Shell form to mirror Go app and allow env expansion
CMD ./${RUST_BINARY_NAME}
