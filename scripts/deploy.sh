#!/usr/bin/env bash
set -Eeuo pipefail

cd "$HOME/docker-test"
command -v pm2 >/dev/null || { echo '먼저 EC2에서 sudo npm install -g pm2를 실행하세요.'; exit 1; }
[[ "$(git branch --show-current)" == main ]] || { echo 'EC2 프로젝트를 main 브랜치로 변경하세요.'; exit 1; }
git pull --ff-only origin main
npm ci
npm run check
npm test
pm2 startOrRestart ecosystem.config.cjs --update-env
pm2 save

for attempt in {1..15}; do
  if curl --fail --silent http://127.0.0.1:3000/health >/dev/null &&
     curl --fail --silent http://127.0.0.1:3000/api/notes >/dev/null; then
    echo '배포 완료'
    exit 0
  fi
  sleep 2
done
pm2 logs docker-test --nostream --lines 30
exit 1
