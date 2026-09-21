#!/usr/bin/env bash
set -Eeuo pipefail

archive=$(realpath "${1:?Application archive required}")
base=/opt/notepad
release="$base/releases/${GITHUB_RUN_ID:?}-${GITHUB_RUN_ATTEMPT:?}"
previous=$(readlink -f "$base/current" || true)
mkdir -p "$release"
tar -xzf "$archive" -C "$release"
cd "$release"
npm ci --omit=dev

activate() {
  ln -sfn "$1" "$base/current.next"
  mv -Tf "$base/current.next" "$base/current"
  sudo -n /usr/bin/systemctl restart notepad
}
healthy() {
  for attempt in {1..15}; do
    if curl --fail --silent http://127.0.0.1:3000/health >/dev/null &&
       curl --fail --silent http://127.0.0.1:3000/api/notes >/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 1
}

if activate "$release" && healthy; then
  echo "Deployment successful: $release"
else
  echo 'Deployment failed.' >&2
  if [[ -n "$previous" && -d "$previous" && "$previous" != "$release" ]]; then
    echo "Restoring $previous" >&2
    activate "$previous"
    healthy || echo 'Rollback health check failed; inspect systemd logs.' >&2
  fi
  exit 1
fi
