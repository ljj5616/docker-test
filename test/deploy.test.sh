#!/usr/bin/env bash
# AWS와 Docker를 호출하지 않고 배포 순서 및 복원 흐름을 검증합니다.
set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
mkdir "$temp/bin"
cat > "$temp/bin/aws" <<'MOCK'
#!/usr/bin/env bash
echo token
MOCK
cat > "$temp/bin/sleep" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
cat > "$temp/bin/docker" <<'MOCK'
#!/usr/bin/env bash
echo "$*" >> "$TRACE"
case "$1 $2" in
  'login --username') cat >/dev/null ;;
  'container inspect') [[ "$3" == docker-test-web ]] ;;
  'pull '*) [[ "$SCENARIO" != pull-fail ]] ;;
  'exec '*) [[ "$SCENARIO" != health-fail ]] ;;
  *) exit 0 ;;
esac
MOCK
chmod +x "$temp/bin/"*
export PATH="$temp/bin:$PATH"
export TRACE="$temp/trace"
image=514287510278.dkr.ecr.ap-northeast-2.amazonaws.com/docker-test:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-1-1
for scenario in success pull-fail health-fail; do
  export SCENARIO="$scenario"
  : > "$TRACE"
  result=0
  bash "$root/scripts/deploy.sh" "$image" > "$temp/output" 2>&1 || result=$?
  case "$scenario" in
    success)
      [[ "$result" == 0 ]]
      grep -q '^run .*docker-test-data:/app/data' "$TRACE"
      grep -q '^rm docker-test-web-previous$' "$TRACE"
      ;;
    pull-fail)
      [[ "$result" != 0 ]]
      if grep -q '^stop ' "$TRACE"; then exit 1; fi
      ;;
    health-fail)
      [[ "$result" != 0 ]]
      grep -q '^rename docker-test-web-previous docker-test-web$' "$TRACE"
      grep -q '^start docker-test-web$' "$TRACE"
      ;;
  esac
  echo "PASS: $scenario"
done
