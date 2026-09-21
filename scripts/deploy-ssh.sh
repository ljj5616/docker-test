#!/usr/bin/env bash
set -Eeuo pipefail

: "${EC2_HOST:?Set EC2_HOST in Actions secrets}"
: "${EC2_USER:?Set EC2_USER in Actions secrets}"
: "${EC2_SSH_KEY:?Set EC2_SSH_KEY in Actions secrets}"
: "${EC2_KNOWN_HOSTS:?Set EC2_KNOWN_HOSTS in Actions secrets}"
[[ "$EC2_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo 'Invalid EC2_HOST'; exit 1; }
[[ "$EC2_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo 'Invalid EC2_USER'; exit 1; }
release_id="${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"
[[ "$release_id" =~ ^[0-9]+-[0-9]+$ ]] || exit 1

ssh_dir=$(mktemp -d)
trap 'rm -rf -- "$ssh_dir"' EXIT
printf '%s\n' "$EC2_SSH_KEY" > "$ssh_dir/key"
printf '%s\n' "$EC2_KNOWN_HOSTS" > "$ssh_dir/known_hosts"
chmod 600 "$ssh_dir/key" "$ssh_dir/known_hosts"
options=(-i "$ssh_dir/key" -o IdentitiesOnly=yes -o BatchMode=yes
  -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$ssh_dir/known_hosts"
  -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
target="$EC2_USER@$EC2_HOST"
remote="/opt/notepad/incoming/$release_id"

ssh "${options[@]}" "$target" "mkdir -p '$remote'"
scp "${options[@]}" artifact/app.tar.gz scripts/deploy.sh "$target:$remote/"
ssh "${options[@]}" "$target" \
  "GITHUB_RUN_ID='$GITHUB_RUN_ID' GITHUB_RUN_ATTEMPT='$GITHUB_RUN_ATTEMPT' bash '$remote/deploy.sh' '$remote/app.tar.gz'"
