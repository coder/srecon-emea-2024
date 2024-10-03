#!/bin/bash
set -euo pipefail

export CODER_CONFIG_DIR="/coder"
CODER_URL="http://coderd:3000"
API_TOKEN_FILE="/coder/api_token"
TOKEN_NAME="startup-script-token"

echo 'Waiting for coderd to be ready...'
until curl -sfL "${CODER_URL}" >/dev/null; do
  echo -n '.'
  sleep 0.5
done;

echo ''

create_first_user() {
  # Clear out existing terraform state, if any.
  rm -f /coder-tf/terraform.tfstate*

  echo "Create first user"
  coder login \
      --first-user-username=${CODER_USER_USERNAME} \
      --first-user-email=${CODER_USER_EMAIL} \
      --first-user-password=${CODER_USER_PASSWORD} \
      --first-user-trial=true \
      "$CODER_URL"
}

login_with_token() {
  if [ ! -f "${API_TOKEN_FILE}" ]; then
    error "Token file does not exist"
    return 1
  fi

  echo "Login with token"
  coder login \
    --token=$(cat "${API_TOKEN_FILE}") \
    "$CODER_URL"
}

create_token() {
  echo "Create token"
  TOKEN=$(coder tokens create -n "${TOKEN_NAME}")
  if [ $? -ne 0 ]; then
    exit 1
  fi

  echo "$TOKEN" > "$API_TOKEN_FILE"
  chmod 600 "$API_TOKEN_FILE"

  echo "API token stored at $API_TOKEN_FILE"
}

error() {
  >&2 echo "ERR: $1"
}

# Attempt to log in with a token (if one exists), otherwise create the first user & generate a token.
if ! login_with_token; then
    error "Login with token failed. Creating first user..."

    if ! create_first_user; then
      error "Failed to create first user"
      exit 1
    fi

    if ! create_token; then
      error "Failed to create token"
      exit 1
    fi
fi

if ! login_with_token; then
  error "Token invalid"
  exit 2
fi

cd /coder-tf
echo "init iac"
terraform init
cd sre-template
echo "init template"
terraform init

cd ..

echo "Plan"
terraform plan \
  -var coder_url="${CODER_URL}"\
  -var coder_api_token="$(cat ${API_TOKEN_FILE})"

echo "Apply"
terraform apply -auto-approve \
  -var coder_url="${CODER_URL}"\
  -var coder_api_token="$(cat ${API_TOKEN_FILE})"