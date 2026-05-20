#!/usr/bin/env bash
set -euo pipefail

./scripts/env.sh

docker compose \
  -p openpark \
  --env-file .env.runtime \
  -f docker-compose.yml \
  pull

docker compose \
  -p openpark \
  --env-file .env.runtime \
  -f docker-compose.yml \
  up -d --remove-orphans

docker image prune -f
