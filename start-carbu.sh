#!/usr/bin/env bash
# Démarre le tunnel Cloudflare, récupère son URL publique, puis (re)lance n8n avec WEBHOOK_URL.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p logs

# Premier lancement depuis un clone : crée .env et une clé de chiffrement si besoin
[ -f .env ] || cp .env.example .env
if ! grep -q '^N8N_ENCRYPTION_KEY=.\+' .env; then
  KEY=$(openssl rand -hex 32 2>/dev/null || python -c "import secrets;print(secrets.token_hex(32))")
  grep -v '^N8N_ENCRYPTION_KEY=' .env > .env.tmp || true
  mv .env.tmp .env
  echo "N8N_ENCRYPTION_KEY=$KEY" >> .env
  echo "      Nouvelle clé de chiffrement écrite dans .env"
fi

echo "[1/6] Démarrage du tunnel..."
# --force-recreate : repart d'un conteneur neuf, donc de logs vides.
# Sans ça, les logs gardent l'URL d'un ancien lancement et on lirait une URL morte.
docker compose up -d --force-recreate tunnel

echo "[2/6] Lecture de l'URL du tunnel..."
URL=""
for i in $(seq 1 60); do
  URL=$(docker compose logs tunnel 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -n 1 || true)
  [ -n "$URL" ] && break
  sleep 2
done
if [ -z "$URL" ]; then
  echo "ERREUR : URL du tunnel introuvable après 120 s. Voir 'docker compose logs tunnel'." >&2
  exit 1
fi
echo "      $URL"

echo "[3/6] Écriture de .env et logs/tunnel-url.txt..."
if [ -f .env ] && grep -q '^WEBHOOK_URL=' .env; then
  grep -v '^WEBHOOK_URL=' .env > .env.tmp || true
  mv .env.tmp .env
fi
echo "WEBHOOK_URL=${URL}/" >> .env
echo "$URL" > logs/tunnel-url.txt

# Par défaut on ne met PAS n8n à jour : une nouvelle version le jour de la démo peut casser
# un workflow, et le pull échoue sans internet. Lancer avec --update pour mettre à jour.
if [ "${1:-}" = "--update" ]; then
  echo "[4/6] Mise à jour et démarrage de n8n..."
  docker compose pull n8n || echo "      Pull impossible, on garde la version locale." >&2
else
  echo "[4/6] Démarrage de n8n (sans mise à jour, --update pour mettre à jour)..."
fi
# n8n est recréé pour lire le nouveau WEBHOOK_URL de .env
docker compose up -d --force-recreate n8n

echo "[5/6] Attente de http://localhost:5678/healthz ..."
READY=0
for i in $(seq 1 90); do
  if curl -fsS http://localhost:5678/healthz >/dev/null 2>&1; then READY=1; break; fi
  sleep 2
done
if [ "$READY" != 1 ]; then
  echo "ERREUR : n8n ne répond pas sur /healthz après 180 s." >&2
  exit 1
fi
echo "      n8n prêt en local."

# Vérifie que le tunnel public mène bien à n8n (le DNS trycloudflare peut prendre quelques secondes)
echo "      Vérification du tunnel public ${URL} ..."
PUBLIC=0
for i in $(seq 1 30); do
  if curl -fsS --max-time 5 "${URL}/healthz" >/dev/null 2>&1; then PUBLIC=1; break; fi
  sleep 2
done
if [ "$PUBLIC" != 1 ]; then
  echo "ERREUR : ${URL} ne répond pas. Relance le script." >&2
  exit 1
fi
echo "      Tunnel OK. Webhooks publics : ${URL}/"

# Éteint puis rallume les deux bots pour que Telegram reçoive la nouvelle URL du tunnel
echo "[6/6] Réenregistrement des webhooks Telegram (WF1 Rapido, WF4 Razmo)..."
N8N_API_KEY=$(grep '^N8N_API_KEY=' .env | cut -d= -f2-)
if [ -z "$N8N_API_KEY" ]; then
  echo "      N8N_API_KEY absent de .env : désactive puis réactive WF1 et WF4 à la main dans n8n." >&2
  exit 0
fi
sleep 5
API=http://localhost:5678/api/v1/workflows
for WF in "2vu1P4DfRSB4YxOp:WF1 Rapido" "5yvBg4c45Jf2vavL:WF4 Razmo"; do
  ID=${WF%%:*}; NAME=${WF#*:}
  curl -fsS -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" "$API/$ID/deactivate" >/dev/null 2>&1
  if curl -fsS -X POST -H "X-N8N-API-KEY: $N8N_API_KEY" "$API/$ID/activate" >/dev/null 2>&1; then
    echo "      $NAME : OK"
  else
    echo "      $NAME : ÉCHEC (clé API invalide ?). Réactive-le à la main dans n8n." >&2
  fi
done
echo "Tout est prêt."
