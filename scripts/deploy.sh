#!/usr/bin/env bash
set -Eeuo pipefail
image="${1:?ECR image required}"
[[ "$image" =~ ^514287510278\.dkr\.ecr\.ap-northeast-2\.amazonaws\.com/docker-test:[a-f0-9]{40}-[0-9]+-[0-9]+$ ]] || exit 1
docker compose version >/dev/null
docker info >/dev/null
cd "${DEPLOY_DIR:-$HOME/docker-test}"
umask 077

# 처음 한 번만 생성합니다. 기존 DB를 재사용하므로 비밀번호를 다시 만들지 않습니다.
if [[ ! -f .env ]]; then
  printf 'MYSQL_PASSWORD=%s\nMYSQL_ROOT_PASSWORD=%s\n' \
    "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" > .env
fi
previous_image=$(sed -n 's/^WEB_IMAGE=//p' .env)
export WEB_IMAGE="$image"
compose=(docker compose -p docker-test --env-file .env -f compose.yaml)
"${compose[@]}" config --quiet
"${compose[@]}" pull
# DB 준비에 실패해도 현재 웹 컨테이너는 계속 실행됩니다.
"${compose[@]}" up -d --no-build --wait --wait-timeout 240 db

legacy=false
if docker container inspect docker-test-web >/dev/null 2>&1; then
  docker stop docker-test-web
  legacy=true
fi
if "${compose[@]}" up -d --no-build --wait --wait-timeout 180 web; then
  awk '!/^WEB_IMAGE=/' .env > .env.next
  printf 'WEB_IMAGE=%s\n' "$image" >> .env.next
  mv .env.next .env
  if [[ "$legacy" == true ]]; then
    docker rm docker-test-web
  fi
  echo "Compose 배포 완료: $image"
  "${compose[@]}" ps
else
  "${compose[@]}" logs --tail 30 web db || true
  if [[ -n "$previous_image" ]]; then
    export WEB_IMAGE="$previous_image"
    "${compose[@]}" up -d --no-build --wait --wait-timeout 120 web || true
  else
    "${compose[@]}" stop web || true
    if [[ "$legacy" == true ]]; then docker start docker-test-web; fi
  fi
  echo '새 버전 배포에 실패했습니다. 위 상태와 로그를 확인하세요.' >&2
  exit 1
fi
