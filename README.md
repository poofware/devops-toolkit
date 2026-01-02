# DevOps Toolkit: Comprehensive README

Welcome to the **DevOps Toolkit**! This toolkit is designed to help you set up robust, modular, and profile-based Docker Compose workflows for your applications. It especially shines with **Go-based microservices**, but it can also be adapted to other projects. 

This README will walk you through:

1. **High-Level Concepts** – Profiles, environment variables, dependency projects, etc.
2. **Basic File Structure** – How the toolkit’s Makefiles and scripts are organized.
3. **Usage Patterns**:
   - **Generic Docker Compose Project** (without Go-specific logic).
   - **Go App + Compose Project** (with built-in Go build/test pipelines).
   - **Rust App + Compose Project** (with Shuttle.rs support).
   - **Frontend Projects** (Next.js & Flutter).
4. **Examples & Common Targets** – Starting containers, running tests, and more.
5. **Integrations & Secrets** – Bitwarden Secrets (BWS), Stripe, LaunchDarkly.
6. **Advanced Usage** – Overriding profiles, environment variable usage, HCP integration, Vercel Deployment Pipeline, Advanced Networking (Gateway, Ngrok, Fly WireGuard), etc.

Read on to learn how to harness these tools and build consistent workflows for your services.

---

## 1. Key Concepts

### 1.1 Profile-Based Design

Docker Compose supports [profiles](https://docs.docker.com/compose/profiles/) to conditionally include or exclude services. This DevOps Toolkit extends that concept by:

- Defining multiple Compose profiles (e.g., `db`, `migrate`, `build_pre_sync`, `app`, `app_pre_async`, `app_post_check`, `app_integration_test`, etc.).
- Providing Make targets that **spin up** these profiles in a specific order.  
  For example:
  - **`db`** profile for a local Postgres container.  
  - **`migrate`** profile for a migration container.  
  - **`build_pre_sync`** profile for blocking pre-build tasks (e.g., WASM compilation) that must complete before the main build.  
  - **`app_pre_async`** profile for long-running tasks **before** the main application (e.g., a Stripe listener).  
  - **`app`** profile for the main application container.  
  - **`app_post_check`** profile for tasks **after** the main app is running (e.g., health checks).  

By chaining these profiles in `make up`, your environment can be started in easily managed stages rather than with a single `docker compose up` that spins up everything at once.

### 1.2 Dealing with the “unassigned” Profile

In the default Compose YAML files under `devops-toolkit/backend/docker/`, **most services are placed under the `unassigned` profile**. This means they **will not** be automatically started by the toolkit’s default `make up` sequence. 

If you want one of these services to actually spin up in your environment, you **must** override its profile in an additional Compose file—often named `override.compose.yaml`. For example, you can override the `go-app` service so it’s placed in the `app` profile, or override a test container so it goes in `app_integration_test`. Once that override is done, the service becomes an active part of the build/up routines.

### 1.3 Overriding Profiles via Compose Files

Compose supports combining multiple files via `COMPOSE_FILE` (colon-separated) so you can:

- Keep a base Compose file in your toolkit (e.g., `go-app.compose.yaml`), where services might be labeled with `profiles: [unassigned]`.
- Add an environment- or project-specific override in your own `override.compose.yaml` that **re-assigns** these services to active profiles like `db`, `app`, `migrate`, etc.
- Use `make up` to start only those services assigned to the relevant profiles (e.g., `app`, `db`, `migrate`, `build_pre_sync`, `app_pre_async`, `app_post_check`).

### 1.4 Makefile Inclusions

The toolkit has **many** small `*.mk` files in `devops-toolkit/backend/make/`. You include them in your project’s root `Makefile` to gain standardized targets such as `build`, `up`, `down`, `clean`, `integration-test`, `ci`, etc.

### 1.5 Environment Variables

Several env vars control how the build and runs happen, for example:

- `ENV` – Distinguishes dev/staging/prod (or `dev-test`).
- `COMPOSE_PROJECT_NAME` – Compose project name (unique for each microservice or service).
- `COMPOSE_NETWORK_NAME` – Name of the shared docker network.
- `WITH_DEPS` – Whether to recursively run targets in **dependency projects**.
- `DEPS` – A space-separated list of “dependency projects” (with optional `key:path` format).

For Go apps, additional variables come into play:

- `APP_NAME`, `APP_PORT` – The name and port for the Go service.
- `APP_URL_FROM_COMPOSE_NETWORK` – The address other containers use to reach your service internally.
- `APP_URL_FROM_ANYWHERE` – The external address (on your local machine).
- `PACKAGES` – Additional internal Go modules to fetch and keep updated.

### 1.6 Dependency Projects

If your app depends on other local projects (e.g., libraries, microservices, or any other codebase following the same Make contract), you can specify them via:

```
WITH_DEPS ?= 1
DEPS := "PROJECT_KEY:/path/to/dependency-project"
```

When you run a Make target (e.g., `make up`), it will also invoke the same target on each listed dependency project, in sequence.

---

## 2. File Structure

A typical repository that uses the DevOps Toolkit might look like this:

```
.
├─ Makefile                          # Root Makefile for your service
├─ devops-toolkit/                   # The toolkit, possibly included as a submodule
│  ├─ bootstrap.mk                   # The entry point for all Makefiles
│  ├─ backend/make/                  # Backend .mk files (Go, Rust, Compose)
│  ├─ frontend/make/                 # Frontend .mk files (Next.js, Flutter)
│  ├─ backend/scripts/               # Reusable Bash scripts
│  └─ backend/docker/                # Base Dockerfiles, docker-compose YAMLs
└─ override.compose.yaml             # (Optional) Additional compose overrides
```

Inside `devops-toolkit/backend` you’ll see numerous scripts (e.g., `fetch_hcp_api_token.sh`, `fetch_hcp_secret.sh`, `encryption.sh`) and Dockerfiles for specialized tasks (Go builds, DB migrations, Stripe CLI, etc.).

---

## 3. Setting Up a **Regular** Docker Compose Project

### 3.1 Minimal Root Makefile (Generic Example)

If you don’t have a Go-based service but still want to leverage this profile-based approach, you can do something like:

```makefile
# -------------------------
# Root Makefile for "my-service"
# -------------------------

SHELL := bash

# 1) Connect devops-toolkit
#    (Assumes devops-toolkit is in the project root or submodule)
REPO_ROOT := $(shell git -C $(CURDIR) rev-parse --show-toplevel 2>/dev/null || echo $(CURDIR))
ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  include $(REPO_ROOT)/devops-toolkit/bootstrap.mk
endif

ENV ?= dev-test
COMPOSE_PROJECT_NAME := my-service
COMPOSE_NETWORK_NAME ?= shared_service_network

# If you have no other local dependency projects, set:
WITH_DEPS ?= 0
DEPS := ""

# Compose files to include (colon-separated)
# Note: $(DEVOPS_TOOLKIT_PATH) is set by bootstrap.mk
COMPOSE_FILE := \
  $(DEVOPS_TOOLKIT_PATH)/backend/docker/db.compose.yaml:\
  $(DEVOPS_TOOLKIT_PATH)/backend/docker/stripe.compose.yaml:\
  override.compose.yaml

# 2) Include project configuration (handles environment, profiles, etc.)
ifndef INCLUDED_COMPOSE_PROJECT_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose_project_configuration.mk
endif

# 3) Include standard project targets (build, up, down, clean, integration-test, etc.)
ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose_project_targets.mk
endif
```

Now, **be aware** that most of the services defined in `db.compose.yaml` or `stripe.compose.yaml` might be set to `profiles: [unassigned]` by default. So to actually **run** them, you need to override them in `override.compose.yaml` (or a similarly named file) to place them in an active profile like `db` or `app`. Example:

```yaml
# override.compose.yaml
services:
  db:
    profiles:
      - db

  stripe-listener:
    profiles:
      - app_pre_async
```

Now, `make up` will see `db` is in the `db` profile, etc., and spin them up in the right order.

### 3.2 Using the Make Targets

From your shell in the project root:

- **`make build`**  
  Builds Docker images for any services whose profiles (or no profile) you’ve assigned to the build sequence.
- **`make up`**  
  Starts containers in an order: `build_pre_sync → db → migrate → app_pre_async → app → app_post_check`. Only those services that are actually assigned these profiles will come up. Note: `build_pre_sync` runs during the build phase.
- **`make integration-test`**  
  (If you set up an integration-test profile) runs that ephemeral test container.
- **`make down`**  
  Stops and removes containers (but leaves images).
- **`make clean`**  
  Fully stops and removes containers, images, volumes, networks, etc.

---

## 4. Setting Up a **Go App** + Docker Compose Project

Many `.mk` files and Dockerfiles in this toolkit focus on simplifying Go builds, tests, and multi-stage Docker builds. Below is a real-world template (inspired by an `account-service` example).

### 4.1 Example: Root Makefile for a Go Service

```makefile
# -------------------------
# Root Makefile for "account-service"
# -------------------------

SHELL := bash

# 1) Connect devops-toolkit
REPO_ROOT := $(shell git -C $(CURDIR) rev-parse --show-toplevel 2>/dev/null || echo $(CURDIR))
ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  include $(REPO_ROOT)/devops-toolkit/bootstrap.mk
endif

# 2) Basic Service Settings
ENV ?= dev-test
COMPOSE_PROJECT_NAME := account-service
COMPOSE_NETWORK_NAME ?= shared_service_network

WITH_DEPS ?= 0
DEPS := ""  # No dependent projects in this example

COMPOSE_FILE := \
  $(DEVOPS_TOOLKIT_PATH)/backend/docker/go-app.compose.yaml:\
  $(DEVOPS_TOOLKIT_PATH)/backend/docker/db.compose.yaml:\
  $(DEVOPS_TOOLKIT_PATH)/backend/docker/stripe.compose.yaml:\
  override.compose.yaml

# 3) Include the Compose Project Configuration
ifndef INCLUDED_COMPOSE_PROJECT_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose_project_configuration.mk
endif

# 4) Go App–specific Compose Configuration
#    - Tells the system which port your Go app runs on, etc.
export APP_NAME := $(COMPOSE_PROJECT_NAME)
export APP_PORT ?= 8080
ifndef INCLUDED_GO_APP_COMPOSE_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/go-app/go_app_compose_configuration.mk
endif

# 5) Additional DB Migrations Config
export COMPOSE_DB_NAME := shared_pg_db
export MIGRATIONS_PATH := migrations
export HCP_APP_NAME_FOR_DB_SECRETS := $(APP_NAME)-$(ENV)

# 6) Stripe Example Config
export STRIPE_WEBHOOK_CONNECTED_EVENTS := \
  account.updated,capability.updated,identity.verification_session.created,\
  identity.verification_session.requires_input,identity.verification_session.verified,\
  identity.verification_session.canceled,payment_intent.created
export STRIPE_WEBHOOK_ROUTE := /api/v1/account/stripe/webhook
export STRIPE_WEBHOOK_CHECK_ROUTE := /api/v1/account/stripe/webhook/check

# 7) Finally, bring in the standard Compose project targets
ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose_project_targets.mk
endif

# 8) Go App Targets (build, test, update, etc.)
PACKAGES := go-middleware go-repositories go-utils go-models
ifndef INCLUDED_GO_APP_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/go-app/go_app_targets.mk
endif
```

### 4.2 Overriding the Test Container with `override.compose.yaml`

Your project might introduce an additional Compose file (`override.compose.yaml`) to properly assign services to active profiles. For instance:

```yaml
# override.compose.yaml

services:
  go-app-integration-test:
    profiles:
      - base_app_integration_test

  go-app-integration-test-override:
    extends:
      file: devops-toolkit/backend/docker/go-app.compose.yaml
      service: go-app-integration-test
    container_name: ${APP_NAME}-integration-test-override_instance
    profiles:
      - app_integration_test
    build:
      context: .
      dockerfile: override.Dockerfile
      target: integration-test-runner-override

  go-app:
    profiles:
      - app

  go-app-health-check:
    profiles:
      - app_post_check

  db:
    profiles:
      - db

  migrate:
    profiles:
      - migrate

  stripe-listener:
    profiles:
      - app_pre_async

  stripe-webhook-check:
    profiles:
      - app_post_check
```

Notice in the base `go-app.compose.yaml` these services might have been defined with `profiles: [unassigned]`. Now in `override.compose.yaml`, we **reassign** them to `app`, `db`, `app_pre_async`, etc. This ensures they actually come up when you run `make up`.

### 4.3 Common Make Targets

- **`make up`**  
  *In order*, it will run `build_pre_sync` (during build), then bring up `db → migrate → app_pre_async → app → app_post_check`.  
  Only those services assigned to these profiles will actually start.
- **`make integration-test`**  
  Spins up the `app_integration_test` profile, which typically runs ephemeral integration tests, then tears down.
- **`make clean`**  
  Removes everything: containers, images, volumes, and networks.

---

## 5. Activating or Excluding Profiles

By default, the internal `make up` logic looks for these profiles in a specific order: `build_pre_sync` (during build phase) → `db → migrate → app_pre_async → app → app_post_check`. Services that remain on `unassigned` are **ignored** (they will never start).

You can also **exclude** certain phases, using environment variables:

- `EXCLUDE_COMPOSE_PROFILE_APP=1` – Skips the `app` profile.  
- `EXCLUDE_COMPOSE_PROFILE_APP_POST_CHECK=1` – Skips the `app_post_check` profile.  

Example:
```bash
EXCLUDE_COMPOSE_PROFILE_APP=1 make up
```
This starts only `db` and `migrate` and `app_pre_async`, skipping the main application container.

---

## 6. Working with Dependency Projects

If your service depends on other local projects—libraries or microservices—that also implement the same Make targets:

1. **Set** `WITH_DEPS=1`.
2. **Define** your dependency projects in `DEPS` as a space-separated list.  
   Example:
   ```makefile
   WITH_DEPS ?= 1
   DEPS := \
     "AUTH_SERVICE:../auth-service" \
     "CONFIG_SERVICE:../config-service"
   ```
3. When you run `make up`, your Makefile will:
   - Jump into each of those `DEPS` paths and run `make up` first.
   - Then proceed with your own `up`.

This fosters a multi-repo environment where one project can automatically spin up any projects it depends on.

---

## 7. Updating Go Modules

If you’re building a Go service that references internal Git repositories (like `github.com/poofware` modules), you can do:

- **`make update`**  
  - This target calls `update_go_packages.sh`, which fetches each package in `PACKAGES` on a given `BRANCH`.
  - Then runs `go mod tidy` and optionally `make vendor` if needed.

Example usage:

```bash
BRANCH=main PACKAGES="go-middleware go-utils go-models" make update
```

---

## 8. HCP & LaunchDarkly Integration

This toolkit includes scripts to:

- **Fetch and cache an HCP (HashiCorp Cloud Platform) API token**.  
- **Encrypt/Decrypt secrets** at rest with `openssl`.
- **Pull secrets from HCP** for your environment, such as database URLs.  
- **Fetch LaunchDarkly flags** for feature toggles in ephemeral containers.

Most features are optional. If your environment doesn’t use HCP or LaunchDarkly, you can simply omit referencing those scripts or environment variables.

---

## 9. Putting It All Together

Here’s the typical flow when using the DevOps Toolkit in your local dev environment:

1. **Set up environment variables** in your shell:
   ```bash
   export HCP_CLIENT_ID="xxx"
   export HCP_CLIENT_SECRET="yyy"
   export HCP_TOKEN_ENC_KEY="some-random-key"
   export UNIQUE_RUNNER_ID="my-username"
   ```
2. **`make build`** – Build Docker images for your service (and any dependency projects if `WITH_DEPS=1`).
3. **`make up`** – Start the environment in a layered approach: `build_pre_sync` (build phase) → `db → migrate → app_pre_async → app → app_post_check`.  
   (All of these assume you **overrode** the `unassigned` profile for each relevant service to something active!)
4. **(Optional) `make integration-test`** – Run an ephemeral container that tests your service’s integration logic.
5. **`make down`** – Stop all containers for this project.
6. **`make clean`** – Clean up everything including volumes, images, etc.

Through the profile-based approach, you can finely tune which containers or tasks run in each step. Overriding or adding new profiles is straightforward by layering additional Compose files.

---

## 10. Setting Up a **Rust App** + Docker Compose Project

The toolkit also supports Rust-based microservices with optional deployment to Shuttle.rs.

### 10.1 Example: Root Makefile for a Rust Service

```makefile
# -------------------------
# Root Makefile for "my-rust-service"
# -------------------------

SHELL := bash

# Connect devops-toolkit
REPO_ROOT := $(shell git -C $(CURDIR) rev-parse --show-toplevel)
ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  include $(REPO_ROOT)/devops-toolkit/bootstrap.mk
endif

ENV ?= dev-test
COMPOSE_PROJECT_NAME := my-rust-service
COMPOSE_NETWORK_NAME ?= my_network

COMPOSE_FILE := $(DEVOPS_TOOLKIT_PATH)/backend/docker/rust-app.compose.yaml

WITH_DEPS := 0
DEPS := ""

ifndef INCLUDED_COMPOSE_PROJECT_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-configurations/compose_project_configuration.mk
endif

export APP_NAME := $(COMPOSE_PROJECT_NAME)
override APP_PORT := 8080

# Rust-specific configuration
RUST_BINARY_NAME := my-rust-service

# Deploy target selection (prod/staging use Shuttle)
PROD_DEPLOY_TARGET := shuttle
STAGING_DEPLOY_TARGET := shuttle
SHUTTLE_PROJECT_NAME := my-rust-service

ifndef INCLUDED_COMPOSE_RUST_APP_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-configurations/compose-file-configurations/rust-app/compose_rust_app_configuration.mk
endif

ifndef INCLUDED_COMPOSE_RUST_APP_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-configurations/compose-file-configurations/rust-app/compose_rust_app_targets.mk
endif

ifndef INCLUDED_COMPOSE_PROJECT_TARGETS
  include $(DEVOPS_TOOLKIT_PATH)/backend/make/compose/compose-project-targets/compose_project_targets.mk
endif
```

### 10.2 Shuttle.rs Deployment

For production/staging deployments, you can use Shuttle.rs. Create a `Shuttle.toml` in your project root:

```toml
name = "my-rust-service"

[build]
features = ["shuttle"]
```

And update your `Cargo.toml` to support shuttle:

```toml
[dependencies]
shuttle-axum = { version = "0.49", optional = true }
shuttle-runtime = { version = "0.49", optional = true }

[features]
default = []
shuttle = ["shuttle-axum", "shuttle-runtime"]
```

Then modify your `main.rs` to support both standalone and Shuttle modes:

```rust
// Shuttle entry point
#[cfg(feature = "shuttle")]
#[shuttle_runtime::main]
async fn shuttle_main() -> shuttle_axum::ShuttleAxum {
    Ok(build_router().into())
}

// Standalone entry point
#[cfg(not(feature = "shuttle"))]
#[tokio::main]
async fn main() {
    // ... your regular axum server code
}
```

### 10.3 Rust-Specific Make Targets

- **`make cargo-build`** – Build the Rust binary locally
- **`make cargo-check`** – Run cargo check
- **`make cargo-test`** – Run cargo tests
- **`make cargo-fmt`** – Format code with rustfmt
- **`make cargo-clippy`** – Run clippy lints
- **`make run`** – Run the server locally (without Docker)
- **`make up ENV=prod`** – Deploy to Shuttle.rs

### 10.4 Deploy Targets

The toolkit supports three deploy targets:

| Target | Use Case |
|--------|----------|
| `fly` | Fly.io deployment (default for Go apps) |
| `vercel` | Vercel deployment (for Next.js/frontend apps) |
| `shuttle` | Shuttle.rs deployment (for Rust apps) |

Set `PROD_DEPLOY_TARGET` and `STAGING_DEPLOY_TARGET` in your Makefile to choose the appropriate target.

---

## 11. Setting Up a **Frontend** Project

The toolkit provides specialized support for Next.js and Flutter (Web/Mobile) applications.

### 11.1 Next.js App

For Next.js applications (often deployed to Vercel), your Makefile should look like this:

```makefile
# -------------------------
# Root Makefile for "nextjs-app"
# -------------------------

SHELL := bash

# 1) Connect devops-toolkit
REPO_ROOT := $(shell git -C $(CURDIR) rev-parse --show-toplevel 2>/dev/null || echo $(CURDIR))
ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  include $(REPO_ROOT)/devops-toolkit/bootstrap.mk
endif

ENV ?= dev-test
APP_NAME := my-nextjs-app

# 2) Next.js Configuration
#    If your frontend needs to talk to a backend:
#    - BACKEND_GATEWAY_PATH: Path to the local backend project (for dev URL resolution)
#    - NEXTJS_BACKEND_ENV_VAR: The env var name in your Next.js app (e.g. NEXT_PUBLIC_API_URL)
BACKEND_GATEWAY_PATH := ../my-backend-service
NEXTJS_BACKEND_ENV_VAR := NEXT_PUBLIC_API_URL

ifndef INCLUDED_NEXTJS_APP_CONFIGURATION
  include $(DEVOPS_TOOLKIT_PATH)/frontend/make/nextjs_app.mk
endif

# 3) Deployment (Vercel)
#    - Requires VERCEL_TOKEN (or BWS_ACCESS_TOKEN)
#    - Requires .vercel/project.json or VERCEL_ORG_ID/VERCEL_PROJECT_ID
DEPLOY_TARGET_FOR_ENV := vercel
```

**Common Targets:**
- `make up` – Runs the app (dev mode). If `BACKEND_GATEWAY_PATH` is set, it resolves the backend URL.
- `make build` – Builds the app.
- `make ci` – Runs lint/test/build pipelines.

#### 11.1.1 Vercel Deployment & Pipeline

The toolkit implements a robust Vercel deployment pipeline:

- **Remote Builds**: Uses the Vercel CLI to perform builds on Vercel's infrastructure.
- **Backend URL Resolution**: If `NEXTJS_BACKEND_ENV_VAR` is set, the toolkit automatically resolves the backend service URL (via `BACKEND_GATEWAY_PATH`) and passes it to Vercel as a `--build-env` variable.
- **Staged Production (`VERCEL_STAGED_PROD`)**: In `prod` environments, the toolkit can deploy to a preview URL first (skipping domain assignment).
- **Automated Health Checks**: After deployment, the toolkit pings a health check endpoint (default `/api/health`) to ensure the new deployment is functional.
- **Auto-Promotion**: If the health check passes and `VERCEL_STAGED_PROD` is enabled, the toolkit automatically promotes the successful deployment to production (assigning the main domain).

**Configuration Variables:**
- `VERCEL_STAGED_PROD := 1` – Enable staged-then-promote flow (default: 1).
- `VERCEL_HEALTHCHECK_PATH := /api/health` – Custom health endpoint.
- `VERCEL_HEALTHCHECK_RETRIES := 20` – Number of health check attempts.

### 11.2 Flutter App (Web & Mobile)

For Flutter applications, the toolkit helps manage web builds, integration tests, and platform-specific running.

```makefile
# -------------------------
# Root Makefile for "flutter-app"
# -------------------------

SHELL := bash

# 1) Connect devops-toolkit
REPO_ROOT := $(shell git -C $(CURDIR) rev-parse --show-toplevel 2>/dev/null || echo $(CURDIR))
ifndef INCLUDED_TOOLKIT_BOOTSTRAP
  include $(REPO_ROOT)/devops-toolkit/bootstrap.mk
endif

ENV ?= dev-test

# 2) Flutter Configuration
#    - FLUTTER_BASE_HREF: Base href for web builds (required)
FLUTTER_BASE_HREF := "/"

# Include Web or Mobile targets as needed
ifndef INCLUDED_WEB_FLUTTER_APP
  include $(DEVOPS_TOOLKIT_PATH)/frontend/make/web_flutter_app.mk
endif
```

**Common Targets:**
- `make run-web` – Runs Flutter for Web (`flutter run -d chrome`).
- `make build-web` – Builds Flutter for Web (`flutter build web --wasm`).
- `make integration-test-web` – Runs integration tests (requires chromedriver).
- `make ci-web` – Runs the full CI pipeline (tests + build).

---

## 12. Integrations & Secrets

The toolkit provides deep integration with external services for secrets management and feature flags.

### 12.1 Secrets Management (Bitwarden Secrets)
The toolkit uses **Bitwarden Secrets Manager (BWS)** to inject secrets into your environment.
- **Requirement**: Set `BWS_ACCESS_TOKEN` in your shell or CI environment.
- **Local Dev**: The target `make env-local` (auto-run in `ENV=dev`) fetches secrets from a BWS project (defined by `ENV_LOCAL_BWS_PROJECT`, defaults to `$(APP_NAME)-$(ENV)`) and writes them to `.env.local`.
- **Containers**: Services can fetch their own secrets at runtime using `fetch_bws_secret.sh`.

### 12.2 Stripe Integration
Two specialized containers facilitate Stripe development:
1.  **`stripe-listener`**: Forwards Stripe events to your local app (requires `STRIPE_WEBHOOK_ROUTE` and `STRIPE_LISTENER_BWS_PROJECT_NAME`).
2.  **`stripe-webhook-check`**: Verifies that your app correctly handles webhooks (requires `STRIPE_WEBHOOK_CHECK_ROUTE`).

**Configuration:**
```makefile
export STRIPE_WEBHOOK_ROUTE := /api/stripe/webhook
export STRIPE_WEBHOOK_CONNECTED_EVENTS := payment_intent.created
export STRIPE_LISTENER_BWS_PROJECT_NAME := my-app-dev
```

### 12.3 LaunchDarkly
Basic constants for LaunchDarkly are provided in `launchdarkly_constants.mk`.
- `LD_SERVER_CONTEXT_KEY` (default: `server`)
- `LD_SERVER_CONTEXT_KIND` (default: `user`)

---

## 13. Advanced Networking & Gateway

For complex microservice setups, the toolkit offers advanced networking flags.

### 12.1 Gateway Mode (`APP_IS_GATEWAY`)
If your service acts as a public gateway that forwards requests to backend dependencies (e.g., a Next.js app or an API Gateway), set:
```makefile
APP_IS_GATEWAY := 1
```
This ensures that:
- Dependency projects inherit the gateway’s public URL configuration.
- `make up` builds/starts the gateway *before* dependencies (so dependencies can use the gateway's network if needed).

### 12.2 Ngrok Integration (`ENABLE_NGROK_FOR_DEV`)
To automatically expose your local service via [ngrok](https://ngrok.com/):
```makefile
ENABLE_NGROK_FOR_DEV := 1
NGROK_AUTHTOKEN_VAR_NAME := NGROK_AUTHTOKEN # (Optional custom env var name)
```
When you run `make up`, an `ngrok` container will start, and `APP_URL_FROM_ANYWHERE` will be automatically set to the public ngrok URL.

### 12.3 Fly.io WireGuard Control (`SKIP_FLY_WIREGUARD`)
By default, deployments to Fly.io (`ENV=prod` or `ENV=staging`) attempt to set up a WireGuard VPN for secure internal access. If your app is a public standalone service (like a static site or simple API) that doesn't need to reach other Fly apps via private network:
```makefile
SKIP_FLY_WIREGUARD := 1
```

---

## 14. Conclusion

**The DevOps Toolkit** streamlines multi-stage Docker Compose usage, especially for Go-based applications. With a minimal root `Makefile`, you gain consistent commands like `make up`, `make down`, `make build`, `make test`, `make ci`, etc.—complete with flexible **profile-based** logic and optional **dependency chaining**.

**Key takeaways**:
- You include a few `.mk` files to get out-of-the-box commands.
- You set environment variables to fit your service name, network, ports, etc.
- You override the `unassigned` profile in your own `override.compose.yaml` to ensure that the services you care about actually run under `app`, `db`, etc.
- You combine Compose files to support a multi-stage, profile-driven container orchestration.

Enjoy building your services with confidence and consistency using the DevOps Toolkit!

---

**Questions or issues?**  
- Check the comments in the included `.mk` files—many contain usage instructions.  
- Examine example services (like `account-service`) to see how advanced features are used.  
- Adapt the toolkit to suit your internal needs.

Happy hacking!
