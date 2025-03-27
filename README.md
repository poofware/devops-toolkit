# devops-toolkit

## Go App Makefile Usage

- Include in root makefile:

`include devops-toolkit/backend/make/go_app.mk`

### Add the following variables to the root makefile:

#### 1. These are required for all go services to integrate with the devops-toolkit.

```make
# Makefile in the "account-service" service root.

APP_NAME := account-service
APP_PORT ?= 8080
ENV ?= dev-test
COMPOSE_NETWORK_NAME ?= shared_service_network

WITH_DEPS ?= 0

DEPS := ""

PACKAGES := go-middleware go-repositories go-utils go-models

ADDITIONAL_COMPOSE_FILES := devops-toolkit/backend/docker/db.compose.yaml:devops-toolkit/backend/docker/stripe.compose.yaml
```

#### 2. These are necessary per what the ADDITIONAL_COMPOSE_FILES require for their usage.

```make
export COMPOSE_DB_NAME := shared_pg_db
export MIGRATIONS_PATH := migrations
export STRIPE_WEBHOOK_ROUTE := /api/v1/account/stripe/webhook
export STRIPE_WEBHOOK_CHECK_ROUTE := /api/v1/account/stripe/webhook/check
export STRIPE_WEBHOOK_EVENTS := account.updated,capability.updated,identity.verification_session.created,identity.verification_session.requires_input,identity.verification_session.verified,identity.verification_session.canceled
```

### You can make your own compose files and add them to the ADDITIONAL_COMPOSE_FILES variable as well.

- Just assign each of your compose services in your custom compose file an available profile. The following profiles are currently supported by the devops toolkit:

```sh
app
db
migrate
app_pre
app_post
```

You assign to your service like so:

```yaml
services:
  my_service:
    image: my_image
    profiles:
      - app_pre
```

You can expect the following behavior based on the profile you assign your service to AND the environment (ENV) you run make for. All functionality is described for the 'up', 'down', 'clean' make targets. The 'build' target will build all profiles regardless of the ENV environment variable.

#### app

- This is the main service and minimum require for 'make up' to work. This is already implemented in the go_app.mk file, and should not most likely be used in your custom compose file.

#### db

- This is the database service profile. If you create your own database service outside of the one defined `db.compose.yaml`, you should assign it this profile.
- This profile only runs when ENV is set to 'dev-test' or 'dev'. Otherwise, the db is a persistent non-docker service that is not managed by the devops-toolkit.

#### migrate

- This is the migration service profile. If you create your own migration service outside of the one defined `db.compose.yaml`, you should assign it this profile. 
- This profile is run for all environments, so it is up to you to ensure that the migrations handle appropriately for each environment, from dev, all the way to prod.

#### app_pre

- This is the pre-start service profile. If you need to run a service before the main app service starts, you should assign it this profile.
- This profile is run for all environments, so it is up to you to ensure that the pre-start services handle appropriately for each environment, from dev, all the way to prod.

#### app_post_check

- This is the post-start service profile. If you need to run a service after the main app service starts, you should assign it this profile.
- This profile is run for all environments, so it is up to you to ensure that the post-start services handle appropriately for each environment, from dev, all the way to prod.

#### app_integration_test

- This is the test service profile. This is already implemented in the go_app.mk file, and should not most likely be used in your custom compose file.

#### app_unit_test

- This is the test service profile. This is already implemented in the go_app.mk file, and should not most likely be used in your custom compose file.
