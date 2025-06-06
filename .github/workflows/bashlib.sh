#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -e

GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-.}
ASSETS_MANIFEST="$GITHUB_WORKSPACE/superset/static/assets/manifest.json"

# Rounded job start time, used to create a unique Cypress build id for
# parallelization so we can manually rerun a job after 20 minutes
NONCE=$(echo "$(date "+%Y%m%d%H%M") - ($(date +%M)%20)" | bc)

# Echo only when not in parallel mode
say() {
  if [[ $(echo "$INPUT_PARALLEL" | tr '[:lower:]' '[:upper:]') != 'TRUE' ]]; then
    echo "$1"
  fi
}

pip-upgrade() {
  say "::group::Upgrade pip"
  pip install --upgrade pip
  say "::endgroup::"
}

# prepare (lint and build) frontend code
npm-install() {
  cd "$GITHUB_WORKSPACE/superset-frontend"

  # cache-restore npm
  say "::group::Install npm packages"
  echo "npm: $(npm --version)"
  echo "node: $(node --version)"
  npm ci
  say "::endgroup::"

  # cache-save npm
}

build-assets() {
  cd "$GITHUB_WORKSPACE/superset-frontend"

  say "::group::Build static assets"
  npm run build
  say "::endgroup::"
}

build-instrumented-assets() {
  cd "$GITHUB_WORKSPACE/superset-frontend"

  say "::group::Build static assets with JS instrumented for test coverage"
  cache-restore instrumented-assets
  if [[ -f "$ASSETS_MANIFEST" ]]; then
    echo 'Skip frontend build because instrumented static assets already exist.'
  else
    npm run build-instrumented
    cache-save instrumented-assets
  fi
  say "::endgroup::"
}

setup-postgres() {
  say "::group::Install dependency for unit tests"
  sudo apt-get update && sudo apt-get install --yes libecpg-dev
  say "::group::Initialize database"
  psql "postgresql://superset:superset@127.0.0.1:15432/superset" <<-EOF
    DROP SCHEMA IF EXISTS sqllab_test_db CASCADE;
    DROP SCHEMA IF EXISTS admin_database CASCADE;
    CREATE SCHEMA sqllab_test_db;
    CREATE SCHEMA admin_database;
EOF
  say "::endgroup::"
}

setup-mysql() {
  say "::group::Initialize database"
  mysql -h 127.0.0.1 -P 13306 -u root --password=root <<-EOF
    SET GLOBAL transaction_isolation='READ-COMMITTED';
    SET GLOBAL TRANSACTION ISOLATION LEVEL READ COMMITTED;
    DROP DATABASE IF EXISTS superset;
    CREATE DATABASE superset DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
    DROP DATABASE IF EXISTS sqllab_test_db;
    CREATE DATABASE sqllab_test_db DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
    DROP DATABASE IF EXISTS admin_database;
    CREATE DATABASE admin_database DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
    CREATE USER 'superset'@'%' IDENTIFIED BY 'superset';
    GRANT ALL ON *.* TO 'superset'@'%';
    FLUSH PRIVILEGES;
EOF
  say "::endgroup::"
}

testdata() {
  cd "$GITHUB_WORKSPACE"
  say "::group::Load test data"
  # must specify PYTHONPATH to make `tests.superset_test_config` importable
  export PYTHONPATH="$GITHUB_WORKSPACE"
  pip install -e .
  superset db upgrade
  superset load_test_users
  superset load_examples --load-test-data
  superset init
  say "::endgroup::"
}

celery-worker() {
  cd "$GITHUB_WORKSPACE"
  say "::group::Start Celery worker"
  # must specify PYTHONPATH to make `tests.superset_test_config` importable
  export PYTHONPATH="$GITHUB_WORKSPACE"
  celery \
    --app=superset.tasks.celery_app:app \
    worker \
      --concurrency=2 \
      --detach \
      --optimization=fair
  say "::endgroup::"
}

cypress-install() {
  cd "$GITHUB_WORKSPACE/superset-frontend/cypress-base"

  cache-restore cypress

  say "::group::Install Cypress"
  npm ci
  say "::endgroup::"

  cache-save cypress
}

cypress-run-all() {
  local USE_DASHBOARD=$1
  local APP_ROOT=$2
  cd "$GITHUB_WORKSPACE/superset-frontend/cypress-base"

  # Start Flask and run it in background
  # --no-debugger means disable the interactive debugger on the 500 page
  # so errors can print to stderr.
  local flasklog="${HOME}/flask.log"
  local port=8081
  CYPRESS_BASE_URL="http://localhost:${port}"
  if [ -n "$APP_ROOT" ]; then
    export SUPERSET_APP_ROOT=$APP_ROOT
    CYPRESS_BASE_URL=${CYPRESS_BASE_URL}${APP_ROOT}
  fi
  export CYPRESS_BASE_URL

  nohup flask run --no-debugger -p $port >"$flasklog" 2>&1 </dev/null &
  local flaskProcessId=$!

  USE_DASHBOARD_FLAG=''
  if [ "$USE_DASHBOARD" = "true" ]; then
    USE_DASHBOARD_FLAG='--use-dashboard'
  fi

  # UNCOMMENT the next few commands to monitor memory usage
  # monitor_memory &  # Start memory monitoring in the background
  # memoryMonitorPid=$!
  python ../../scripts/cypress_run.py --parallelism $PARALLELISM --parallelism-id $PARALLEL_ID --group $PARALLEL_ID --retries 5 $USE_DASHBOARD_FLAG
  # kill $memoryMonitorPid

  # After job is done, print out Flask log for debugging
  echo "::group::Flask log for default run"
  cat "$flasklog"
  echo "::endgroup::"
  # make sure the program exits
  kill $flaskProcessId
}

eyes-storybook-dependencies() {
  say "::group::install eyes-storyook dependencies"
  sudo apt-get update -y && sudo apt-get -y install gconf-service ca-certificates libxshmfence-dev fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgbm1 libgcc1 libgconf-2-4 libglib2.0-0 libgdk-pixbuf2.0-0 libgtk-3-0 libnspr4 libnss3 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 lsb-release xdg-utils libappindicator1
  say "::endgroup::"
}

monitor_memory() {
  # This is a small utility to monitor memory usage. Useful for debugging memory in GHA.
  # To use wrap your command as follows
  #
  # monitor_memory &  # Start memory monitoring in the background
  # memoryMonitorPid=$!
  # YOUR_COMMAND_HERE
  # kill $memoryMonitorPid
  while true; do
    echo "$(date) - Top 5 memory-consuming processes:"
    ps -eo pid,comm,%mem --sort=-%mem | head -n 6  # First line is the header, next 5 are top processes
    sleep 2
  done
}

cypress-run-applitools() {
  cd "$GITHUB_WORKSPACE/superset-frontend/cypress-base"

  local flasklog="${HOME}/flask.log"
  local port=8081
  local cypress="./node_modules/.bin/cypress run"
  local browser=${CYPRESS_BROWSER:-chrome}

  export CYPRESS_BASE_URL="http://localhost:${port}"

  nohup flask run --no-debugger -p $port >"$flasklog" 2>&1 </dev/null &
  local flaskProcessId=$!

  $cypress --spec "cypress/applitools/**/*" --browser "$browser" --headless

  say "::group::Flask log for default run"
  cat "$flasklog"
  say "::endgroup::"

  # make sure the program exits
  kill $flaskProcessId
}
