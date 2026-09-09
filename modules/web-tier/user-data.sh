#!/bin/bash
set -euo pipefail

IMAGE='${container_image}'

retry() {
  for attempt in 1 2 3 4 5; do
    if "$@"; then
      return 0
    fi
    sleep 10
  done
  return 1
}

# t4g.nano has 512 MiB RAM: create swap before package installation.
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
fi
swapon /swapfile || true
if ! grep -q '^/swapfile ' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# AL2023 repositories and the public image registry are reachable over IPv6.
retry dnf install -y docker
systemctl enable --now docker

TOKEN=$(curl --fail --silent --show-error --max-time 10 -X PUT \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
  http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl --fail --silent --show-error --max-time 10 \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

# Pull anonymously: no registry credentials or extra instance IAM role are needed.
retry docker pull "$IMAGE"
docker rm -f web-tier 2>/dev/null || true

# Host networking exposes NGINX's IPv6 listener without a Docker bridge/NAT setup.
docker run -d --name web-tier \
  --network host \
  --restart unless-stopped \
  --memory 64m --memory-swap 64m --pids-limit 64 \
  --log-driver local --log-opt max-size=5m --log-opt max-file=2 \
  --env WEB_INSTANCE_ID="$INSTANCE_ID" \
  "$IMAGE"

for attempt in $(seq 1 30); do
  if curl --fail --silent --max-time 3 http://127.0.0.1:80/ >/dev/null; then
    docker inspect --format 'CONTAINER_READY image={{.Config.Image}} running={{.State.Running}} network={{.HostConfig.NetworkMode}} restart={{.HostConfig.RestartPolicy.Name}}' web-tier
    docker exec web-tier nginx -v
    exit 0
  fi
  sleep 2
done
docker logs web-tier
exit 1
