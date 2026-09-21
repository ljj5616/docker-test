#!/usr/bin/env bash
set -Eeuo pipefail

: "${EC2_HOST:?Set EC2_HOST in Actions secrets}"
: "${EC2_USER:?Set EC2_USER in Actions secrets}"
: "${EC2_SSH_KEY:?Set EC2_SSH_KEY in Actions secrets}"
: "${EC2_KNOWN_HOSTS:?Set EC2_KNOWN_HOSTS in Actions secrets}"
[[ "$EC2_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || { echo 'Invalid EC2_HOST'; exit 1; }
[[ "$EC2_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo 'Invalid EC2_USER'; exit 1; }

ssh_dir=$(mktemp -d)
trap 'rm -rf -- "$ssh_dir"' EXIT
printf '%s\n' "$EC2_SSH_KEY" > "$ssh_dir/key"
printf '%s\n' "$EC2_KNOWN_HOSTS" > "$ssh_dir/known_hosts"
chmod 600 "$ssh_dir/key" "$ssh_dir/known_hosts"
options=(-i "$ssh_dir/key" -o IdentitiesOnly=yes -o BatchMode=yes
  -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$ssh_dir/known_hosts"
  -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3)
target="$EC2_USER@$EC2_HOST"
: "${DEPLOY_IMAGE:?Missing ECR image}"
[[ "$DEPLOY_IMAGE" =~ ^514287510278\.dkr\.ecr\.ap-northeast-2\.amazonaws\.com/docker-test:[a-f0-9]{40}-[0-9]+-[0-9]+$ ]] || { echo 'Invalid image'; exit 1; }
# AWS 개인키는 GitHub에 두고, ECR 로그인 토큰만 SSH 표준입력으로 전달합니다.
aws ecr get-login-password --region ap-northeast-2 | \
  ssh "${options[@]}" "$target" 'docker login --username AWS --password-stdin 514287510278.dkr.ecr.ap-northeast-2.amazonaws.com'
ssh "${options[@]}" "$target" 'mkdir -p "$HOME/docker-test"'
scp "${options[@]}" compose.yaml "$target:docker-test/compose.yaml"
ssh "${options[@]}" "$target" "bash -s -- '$DEPLOY_IMAGE'" < scripts/deploy.sh
