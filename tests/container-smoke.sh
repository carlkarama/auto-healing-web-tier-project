#!/usr/bin/env bash
set -euo pipefail

image="${1:-auto-healing-web-tier:local}"
container="web-tier-smoke-$(date +%s)-$$"
instance_id="smoke-test-instance"
scratch="$(mktemp -d)"

cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  docker logs --tail 30 "$container" >&2 2>/dev/null || true
  exit 1
}

command -v docker >/dev/null || fail 'Docker is required.'
command -v curl >/dev/null || fail 'curl is required.'
architecture="$(docker image inspect --format '{{.Architecture}}' "$image")"
[[ "$architecture" == arm64 ]] || fail "Expected ARM64 image; found $architecture."

started_at="$(date +%s)"
docker run --detach --name "$container" --platform linux/arm64 \
  --publish 127.0.0.1::80 --env "WEB_INSTANCE_ID=$instance_id" \
  --memory 64m --memory-swap 64m --pids-limit 64 \
  --restart unless-stopped "$image" >/dev/null
response_is_valid() {
  local address status
  # Docker may reassign an ephemeral host port when restarting the container.
  address="$(docker port "$container" 80/tcp 2>/dev/null)" || return 1
  [[ -n "$address" ]] || return 1
  status="$(curl --silent --show-error --max-time 3 \
    --dump-header "$scratch/headers" --output "$scratch/body" \
    --write-out '%{http_code}' "http://$address/" 2>/dev/null)" || return 1
  [[ "$status" == 200 ]] || return 1
  grep -q 'Welcome to nginx!' "$scratch/body" || return 1
  tr -d '\r' < "$scratch/headers" > "$scratch/clean-headers"
  grep -Eiq "^X-Web-Instance: $instance_id$" "$scratch/clean-headers" || return 1
  grep -Eiq '^Cache-Control: no-store$' "$scratch/clean-headers"
}

wait_for_response() {
  local attempt
  for attempt in {1..30}; do
    if response_is_valid; then return 0; fi
    sleep 1
  done
  fail 'Expected HTTP 200, welcome page, instance header and no-store header.'
}

wait_for_health() {
  local attempt health
  for attempt in {1..60}; do
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container")"
    [[ "$health" != missing ]] || fail 'Image has no Docker HEALTHCHECK.'
    if [[ "$health" == healthy ]]; then return 0; fi
    sleep 1
  done
  fail 'Docker health check did not become healthy.'
}

wait_for_response
wait_for_health
ipv6_body="$(docker exec "$container" wget -q -T 3 -O - 'http://[::1]/')" \
  || fail 'NGINX did not respond over IPv6 loopback.'
[[ "$ipv6_body" == *'Welcome to nginx!'* ]] || fail 'IPv6 response lacks welcome page.'

# Docker activates its restart policy after a successful ten-second start.
while (( $(date +%s) - started_at < 11 )); do sleep 1; done
previous_restarts="$(docker inspect --format '{{.RestartCount}}' "$container")"
docker exec "$container" nginx -s quit
restarted=false
for attempt in {1..30}; do
  restarts="$(docker inspect --format '{{.RestartCount}}' "$container")"
  if (( restarts > previous_restarts )); then
    restarted=true
    break
  fi
  sleep 1
done
[[ "$restarted" == true ]] || fail 'Container did not restart after NGINX exited.'
wait_for_response
wait_for_health

printf 'PASS: ARM64, HTTP 200, welcome page, headers, IPv6, health check and automatic restart.\n'
