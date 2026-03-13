#!/usr/bin/env bash
set -euo pipefail

# Defaults (edit these if you'd like other defaults)
DEFAULT_NAME="radudinca/wurfare-intro:latest"
DEFAULT_SSH="ubuntu@82.23.138.76"
DEFAULT_KEY="/home/radu/.ssh/wurfare_rsa"
DEFAULT_ENV_FILE=".env.prod"

# Accept positional args: ./script.sh <image-name> <ssh-destination> <key-path> <env-file>
NAME="${1:-}"
SSH_LOCATION="${2:-}"
KEY_PATH="${3:-}"
ENV_FILE="${4:-}"

# Prompt for missing values (use defaults when user presses Enter)
if [[ -z "$NAME" || -z "$SSH_LOCATION" || -z "$KEY_PATH" || -z "$ENV_FILE" ]]; then
  echo "Some required parameters are missing."
  echo "You can leave any of the following prompts empty to use the default value."
fi

if [[ -z "$NAME" ]]; then
  NAME="${NAME:-$DEFAULT_NAME}"
fi

if [[ -z "$SSH_LOCATION" ]]; then
  SSH_LOCATION="${SSH_LOCATION:-$DEFAULT_SSH}"
fi

if [[ -z "$KEY_PATH" ]]; then
  KEY_PATH="${KEY_PATH:-$DEFAULT_KEY}"
fi

if [[ -z "$ENV_FILE" ]]; then
  ENV_FILE="${ENV_FILE:-$DEFAULT_ENV_FILE}"
fi

# Build the project using Bun
echo "Building project with Yarn..."
# bun --env-file="$ENV_FILE" run build

# Build the Docker image for linux/amd64
echo "Building Docker image '$NAME' (platform linux/amd64)..."
docker build -t "$NAME" . --platform linux/amd64

echo "Checking SSH access to ${SSH_LOCATION}..."
SSH_CMD="ssh"
if [[ -n "$KEY_PATH" ]]; then
  SSH_CMD="ssh -i $KEY_PATH"
fi

if ! $SSH_CMD -o BatchMode=yes -o ConnectTimeout=5 "$SSH_LOCATION" 'echo ok' ; then
  echo "Warning: quick SSH check failed. We'll still attempt the upload, but verify SSH access and that the remote user can run docker."
  read -r -p "Continue anyway? (y/N): " yn
  case "$yn" in
    [Yy]*) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

echo "Streaming image to ${SSH_LOCATION} and loading it into remote Docker..."
# Stream the saved image (gzip for compression) over SSH and load it remotely.
# This requires 'docker' to be available to the SSH user on the remote host.
docker save "$NAME" | gzip -c | $SSH_CMD "$SSH_LOCATION" 'gunzip -c | docker load'

echo "Done — image '$NAME' should now be available on ${SSH_LOCATION} (as the same tag)."
