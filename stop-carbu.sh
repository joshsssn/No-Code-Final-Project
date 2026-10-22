#!/usr/bin/env bash
# Arrête les conteneurs Carbu Radar sans rien supprimer (jamais de 'down -v').
set -euo pipefail
cd "$(dirname "$0")"
docker compose stop
