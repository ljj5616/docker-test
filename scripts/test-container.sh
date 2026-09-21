#!/usr/bin/env bash
set -Eeuo pipefail
export WEB_IMAGE=docker-test:ci
export MYSQL_PASSWORD=ci-app-password
export MYSQL_ROOT_PASSWORD=ci-root-password
export WEB_PORT=0
project="docker-test-ci-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"
export DB_VOLUME_NAME="$project-data"
compose=(docker compose -p "$project" -f compose.yaml)
cleanup() {
  "${compose[@]}" down -v --remove-orphans
}
trap cleanup EXIT
"${compose[@]}" up -d --no-build --wait --wait-timeout 240
"${compose[@]}" exec -T web node --input-type=module -e '
  const health = await (await fetch("http://127.0.0.1:3000/health")).json();
  if (health.storage !== "mysql") throw new Error("MySQL storage not enabled");
  const response = await fetch("http://127.0.0.1:3000/api/notes", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content: "한글 메모 📝 SQL quote '\'' CI persistence" })
  });
  if (response.status !== 201) throw new Error("Save failed");
'
# HTTP 응답뿐 아니라 실제 MySQL 테이블에도 저장됐는지 확인합니다.
count=$("${compose[@]}" exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE" -Nse "SELECT COUNT(*) FROM notes"')
[[ "$count" == 1 ]]
# 컨테이너를 삭제해도 DB 볼륨이 유지되는지 검증합니다.
"${compose[@]}" down
"${compose[@]}" up -d --no-build --wait --wait-timeout 240
"${compose[@]}" exec -T web node --input-type=module -e '
  const response = await fetch("http://127.0.0.1:3000/api/notes");
  const notes = await response.json();
  if (!response.ok || notes.length !== 1 || !notes[0].content.includes("한글 메모 📝")) {
    throw new Error("MySQL volume persistence failed");
  }
'
echo 'PASS: Compose web + MySQL save, SQL query, and volume persistence'
