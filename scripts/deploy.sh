#!/usr/bin/env bash
set -Eeuo pipefail
image="${1:?ECR image required}"
[[ "$image" =~ ^514287510278\.dkr\.ecr\.ap-northeast-2\.amazonaws\.com/docker-test:[a-f0-9]{40}-[0-9]+-[0-9]+$ ]] || exit 1
command -v docker >/dev/null
docker info >/dev/null
docker pull "$image"

# 기존 Docker 메모를 유지하고, 이전 컨테이너는 실패 시 복원할 수 있게 보관합니다.
name=docker-test-web
backup=docker-test-web-previous
if docker container inspect "$backup" >/dev/null 2>&1; then
  echo '이전 복구용 컨테이너가 남아 있습니다. docker ps -a로 확인하세요.' >&2
  exit 1
fi
had_previous=false
if docker container inspect "$name" >/dev/null 2>&1; then
  docker stop "$name"
  docker rename "$name" "$backup"
  had_previous=true
fi
rollback() {
  docker logs "$name" --tail 30 2>/dev/null || true
  docker rm -f "$name" >/dev/null 2>&1 || true
  if [[ "$had_previous" == true ]]; then
    docker rename "$backup" "$name"
    docker start "$name"
  fi
}
trap rollback ERR

docker run -d --name "$name" --restart unless-stopped \
  -p 3000:3000 -v docker-test-data:/app/data "$image"
healthy=false
for attempt in {1..20}; do
  if docker exec "$name" node --input-type=module -e '
    for (const route of ["/health", "/api/notes"]) {
      const response = await fetch("http://127.0.0.1:3000" + route, { signal: AbortSignal.timeout(3000) });
      if (!response.ok) process.exit(1);
    }
  ' >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 2
done
[[ "$healthy" == true ]]
trap - ERR
if [[ "$had_previous" == true ]]; then
  docker rm "$backup"
fi
echo "배포 완료: $image"
