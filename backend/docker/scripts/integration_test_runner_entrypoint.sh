#!/bin/bash
set -e

source ./health_check.sh

# Finally, run the integration tests
exec ./integration_test -test.v
