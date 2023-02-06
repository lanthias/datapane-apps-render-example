#!/usr/bin/env bash

set -euo pipefail

APP_NOTEBOOK="app.ipynb"
APP_PY="app.py"

error() {
  echo "$1" >&2
}

extract_notebook() {
  local notebook="$1"
  local output="$2"
  jupyter nbconvert --to python "$notebook" --output "$output"
}

# Check flyctl is available, and logged in:
if ! command -v flyctl >/dev/null; then
  error "flyctl not found, please install it, and login"
  error ""
  error "install: https://fly.io/docs/hands-on/install-flyctl/"
  error "login: https://fly.io/docs/hands-on/sign-in/"
  exit 1
fi
if ! flyctl auth whoami 2&>/dev/null; then
  error "flyctl not logged in, please login with 'flyctl auth login'"
  error ""
  error "login: https://fly.io/docs/hands-on/sign-in/"
  exit 1
fi

if ! test -f fly.toml; then
  # guides the user through setting up a Fly app
  flyctl launch --no-deploy

  # HACK: workaround fly selecting a builder that doens't support sqlite
  # we require more system libs, so change to the full builder
  # updates 'fly.toml' as follows:
  # [build]
  # -  builder = "paketobuildpacks/builder:base"
  # +  builder = "paketobuildpacks/builder:full"
  sed -i 's|paketobuildpacks/builder:base|paketobuildpacks/builder:full|' fly.toml

  # setup how to execute the app
  echo "web: python ${APP_PY}" > Procfile

  # disable autoscaling, Apps store state in memory
  flyctl autoscale disable
fi

# extract the notebook to a python file
extract_notebook "$APP_NOTEBOOK" "$APP_PY"

# deploy the app, using Fly's remote builder
# bug: must specify '-c fly.toml' otherwise environment variables aren't included
flyctl deploy --remote-only -c 'fly.toml'
