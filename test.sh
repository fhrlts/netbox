#!/bin/bash
# Runs the original NetBox unit tests and tests whether all initializers work.
# Usage:
#   ./test.sh latest
#   ./test.sh v2.9.7
#   ./test.sh develop-2.10
#   IMAGE='netboxcommunity/netbox:latest'        ./test.sh
#   IMAGE='netboxcommunity/netbox:v2.9.7'        ./test.sh
#   IMAGE='netboxcommunity/netbox:develop-2.10'  ./test.sh
#   export IMAGE='netboxcommunity/netbox:latest';       ./test.sh
#   export IMAGE='netboxcommunity/netbox:v2.9.7';       ./test.sh
#   export IMAGE='netboxcommunity/netbox:develop-2.10'; ./test.sh

# exit when a command exits with an exit code != 0
set -e

# IMAGE is used by `docker-compose.yml` do determine the tag
# of the Docker Image that is to be used
if [ "${1}x" != "x" ]; then
  # Use the command line argument
  export IMAGE="netboxcommunity/netbox:${1}"
else
  export IMAGE="${IMAGE-netboxcommunity/netbox:latest}"
fi

# Ensure that an IMAGE is defined
if [ -z "${IMAGE}" ]; then
  echo "⚠️ No image defined"

  if [ -z "${DEBUG}" ]; then
    exit 1
  else
    echo "⚠️ Would 'exit 1' here, but DEBUG is '${DEBUG}'."
  fi
fi

# The docker compose command to use
doco="docker compose --file docker-compose.test.yml --project-name netbox_docker_test"

test_setup() {
  echo "🏗 Setup up test environment"
  $doco up --detach --quiet-pull --wait --force-recreate --renew-anon-volumes --no-start
  $doco start postgres
  $doco start redis
  $doco start redis-cache
}

test_netbox_unit_tests() {
  echo "⏱ Running NetBox Unit Tests"
  $doco run --rm netbox /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py test
}

test_compose_db_setup() {
  echo "⏱ Running NetBox DB migrations"
  $doco run --rm netbox /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py migrate
}

test_cleanup() {
  echo "💣 Cleaning Up"
  $doco down --volumes
}

echo "🐳🐳🐳 Start testing '${IMAGE}'"

# Make sure the cleanup script is executed
trap test_cleanup EXIT ERR
test_setup

test_netbox_unit_tests
test_compose_db_setup

echo "🐳🐳🐳 Done testing '${IMAGE}'"
