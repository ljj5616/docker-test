#!/usr/bin/env bash
set -Eeuo pipefail
name="docker-test-ci-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" docker-test:ci
ready() {
  for attempt in {1..20}; do
    if docker exec "$name" node -e 'fetch("http://127.0.0.1:3000/health").then(r => { if (!r.ok) process.exit(1); }).catch(() => process.exit(1))'; then
      return 0
    fi
    sleep 1
  done
  docker logs "$name"
  return 1
}
ready
docker exec "$name" node --input-type=module -e '
  const response = await fetch("http://127.0.0.1:3000/api/notes", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content: "CI container persistence test" })
  });
  if (response.status !== 201) throw new Error("Save failed");
'
docker restart "$name"
ready
docker exec "$name" node --input-type=module -e '
  const response = await fetch("http://127.0.0.1:3000/api/notes");
  const notes = await response.json();
  if (!response.ok || !notes.some(n => n.content === "CI container persistence test")) {
    throw new Error("Restart persistence failed");
  }
'
