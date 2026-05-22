#!/usr/bin/env bash
set -euo pipefail

./scripts/env.sh

COMPOSE="docker compose -p openpark --env-file .env.runtime -f docker-compose.yml"

$COMPOSE pull

$COMPOSE up -d postgresql

$COMPOSE run --rm parking-lot-backend alembic upgrade head

$COMPOSE up -d --remove-orphans

docker image prune -f
