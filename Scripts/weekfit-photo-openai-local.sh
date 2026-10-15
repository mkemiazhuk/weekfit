#!/usr/bin/env bash
# Prints the LAN URL to paste into Xcode for live OpenAI photo logging.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
PORT="${PORT:-8080}"

echo "WeekFit photo → OpenAI local setup"
echo "---------------------------------"
if [[ -z "${IP}" ]]; then
  echo "Could not detect Wi‑Fi IP (en0/en1). Connect to Wi‑Fi and retry."
else
  echo "Mac LAN IP:  ${IP}"
  echo "API base:    http://${IP}:${PORT}"
  echo
  echo "Xcode → Scheme → Run → Arguments Passed On Launch:"
  echo "  -WeekFitCloudAPIBaseURL"
  echo "  http://${IP}:${PORT}"
fi
echo
echo "Then:"
echo "  cd ${ROOT}/backend/food-photo-recognize"
echo "  cp -n .env.example .env   # add OPENAI_API_KEY"
echo "  npm start"
echo "  curl -s http://127.0.0.1:${PORT}/healthz"
