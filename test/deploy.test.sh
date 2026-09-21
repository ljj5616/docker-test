#!/usr/bin/env bash
# 실제 AWS와 Docker 대신 모의 명령으로 배포 전환과 실패 처리를 검사합니다.
set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
mkdir "$temp/bin"
cat > "$temp/bin/docker" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$TRACE"
case "$*" in
  'container inspect docker-test-web') [[ "$SCENARIO" != upgrade-fail ]] ;;
  'compose '*pull) [[ "$SCENARIO" != pull-fail ]] ;;
  'compose '*'up '*db) [[ "$SCENARIO" != db-fail ]] ;;
  'compose '*'up '*web)
    if [[ "$SCENARIO" == web-fail ]]; then exit 1; fi
    if [[ "$SCENARIO" == upgrade-fail && "$WEB_IMAGE" != "$OLD_IMAGE" ]]; then exit 1; fi
    ;;
  *) exit 0 ;;
esac
MOCK
chmod +x "$temp/bin/docker"
export PATH="$temp/bin:$PATH"
export TRACE="$temp/trace"
export OLD_IMAGE=514287510278.dkr.ecr.ap-northeast-2.amazonaws.com/docker-test:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-1-1
image=514287510278.dkr.ecr.ap-northeast-2.amazonaws.com/docker-test:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-2-1
for scenario in success pull-fail db-fail web-fail upgrade-fail; do
  export SCENARIO="$scenario"
  export DEPLOY_DIR="$temp/$scenario"
  mkdir "$DEPLOY_DIR"
  printf 'MYSQL_PASSWORD=test\nMYSQL_ROOT_PASSWORD=test-root\n' > "$DEPLOY_DIR/.env"
  if [[ "$scenario" == upgrade-fail ]]; then printf 'WEB_IMAGE=%s\n' "$OLD_IMAGE" >> "$DEPLOY_DIR/.env"; fi
  : > "$TRACE"
  result=0
  bash "$root/scripts/deploy.sh" "$image" > "$temp/output" 2>&1 || result=$?
  case "$scenario" in
    success)
      [[ "$result" == 0 ]]
      grep -q "^WEB_IMAGE=$image$" "$DEPLOY_DIR/.env"
      grep -q '^rm docker-test-web$' "$TRACE"
      ;;
    pull-fail|db-fail)
      [[ "$result" != 0 ]]
      if grep -q '^stop ' "$TRACE"; then exit 1; fi
      ;;
    web-fail)
      [[ "$result" != 0 ]]
      grep -q '^start docker-test-web$' "$TRACE"
      if grep -q '^WEB_IMAGE=' "$DEPLOY_DIR/.env"; then exit 1; fi
      ;;
    upgrade-fail)
      [[ "$result" != 0 ]]
      grep -q "^WEB_IMAGE=$OLD_IMAGE$" "$DEPLOY_DIR/.env"
      [[ "$(grep -c 'up .*web$' "$TRACE")" == 2 ]]
      ;;
  esac
  echo "PASS: $scenario"
done
