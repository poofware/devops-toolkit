# syntax=docker/dockerfile:1.4

ARG RUST_VERSION=1.83

# ────────────────────────────────  Chef (for cargo-chef caching) ────────────────────────────────
FROM rust:${RUST_VERSION}-slim-bookworm AS chef
# Pin cargo-chef to version compatible with Rust 1.83 (avoids edition2024 dependency issues)
RUN cargo install cargo-chef --version 0.1.67 --locked
WORKDIR /app

# ────────────────────────────────  Planner ────────────────────────────────
# OPTIMIZATION: Only copy dependency files, not source code
# This layer only invalidates when Cargo.toml/Cargo.lock change
FROM chef AS planner
COPY Cargo.toml Cargo.lock ./
# Create dummy source files so cargo-chef can analyze dependencies
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    echo "// dummy lib" > src/lib.rs
RUN cargo chef prepare --recipe-path recipe.json

# ────────────────────────────────  Builder ────────────────────────────────
FROM chef AS builder

ARG RUST_BUILD_PROFILE=release
ARG RUST_BINARY_NAME

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=planner /app/recipe.json recipe.json

# Build dependencies - this is the caching layer
RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=rust-target,target=/app/target \
    cargo chef cook --${RUST_BUILD_PROFILE} --recipe-path recipe.json

# Build application
COPY . .
RUN --mount=type=cache,id=cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=rust-target,target=/app/target \
    cargo build --${RUST_BUILD_PROFILE} && \
    cp /app/target/${RUST_BUILD_PROFILE}/${RUST_BINARY_NAME} /${RUST_BINARY_NAME}

# ────────────────────────────────  Development (with hot-reload) ────────────────────────────────
FROM rust:${RUST_VERSION}-slim-bookworm AS dev

ARG APP_NAME
ARG APP_PORT=8080
ARG RUST_BINARY_NAME

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-watch for hot reloading
# Use --locked to respect the crate's Cargo.lock and avoid pulling newer incompatible deps
RUN cargo install cargo-watch --version 8.4.1 --locked

WORKDIR /app
COPY . .

ENV PORT=${APP_PORT}
EXPOSE ${APP_PORT}

# Default command for development with hot-reload
CMD ["cargo", "watch", "-x", "run"]

# ────────────────────────────────  Runtime (production) ────────────────────────────────
FROM debian:bookworm-slim AS runner

ARG APP_NAME
ARG APP_PORT=8080
ARG RUST_BINARY_NAME
ARG RUST_BUILD_PROFILE=release

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the built binary (from root, where we copied it out of the cache mount)
COPY --from=builder /${RUST_BINARY_NAME} /app/app

ENV PORT=${APP_PORT}
EXPOSE ${APP_PORT}

# Run the binary
ENTRYPOINT ["/app/app"]

# ────────────────────────────────  Health Check ────────────────────────────────
FROM debian:bookworm-slim AS health-check

ARG APP_URL_FROM_ANYWHERE

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

ENV APP_URL_FROM_ANYWHERE=${APP_URL_FROM_ANYWHERE}

# Health check script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Checking health at ${APP_URL_FROM_ANYWHERE}/health..."\n\
for i in {1..30}; do\n\
  if curl -sf "${APP_URL_FROM_ANYWHERE}/health" > /dev/null 2>&1; then\n\
    echo "Health check passed!"\n\
    exit 0\n\
  fi\n\
  echo "Attempt $i failed, retrying in 2s..."\n\
  sleep 2\n\
done\n\
echo "Health check failed after 30 attempts"\n\
exit 1' > /health-check.sh && chmod +x /health-check.sh

CMD ["/health-check.sh"]
