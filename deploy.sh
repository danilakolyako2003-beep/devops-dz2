#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

VERSION=${1:?укажите версию: bash deploy.sh 5.0}
PREFIX=kolyako-01
PORT=8003
REGISTRY=localhost:6001
IMAGE=$REGISTRY/$PREFIX/probe:$VERSION
registry_container=$PREFIX-registry

if [[ $(docker info --format '{{.Swarm.LocalNodeState}}') == inactive ]]; then
  docker swarm init --advertise-addr eth0 >/dev/null
  echo 'Swarm инициализирован'
fi

if ! docker container inspect "$registry_container" >/dev/null 2>&1; then
  docker run -d --restart unless-stopped --name "$registry_container" \
    -p 127.0.0.1:6001:5000 -v "$registry_container:/var/lib/registry" registry:2
elif [[ $(docker inspect -f '{{.State.Running}}' "$registry_container") == false ]]; then
  docker start "$registry_container"
fi

SECONDS=0
until curl -fsS -m 2 "$REGISTRY/v2/" >/dev/null 2>&1; do
  if (( SECONDS >= 45 )); then echo 'Реестр не ответил за 45 секунд' >&2; exit 1; fi
  sleep 1
done

docker build --progress=plain --build-arg VERSION="$VERSION" -t "$IMAGE" .
docker push "$IMAGE"
VERSION="$VERSION" timeout 180 docker stack deploy --detach=false -c stack.yaml "$PREFIX"

SECONDS=0
until curl -fsS -m 2 "127.0.0.1:$PORT/notes" 2>/dev/null; do
  if (( SECONDS >= 90 )); then echo 'Приложение не ответило за 90 секунд' >&2; exit 1; fi
  sleep 2
done
