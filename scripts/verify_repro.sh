#!/usr/bin/env bash
# 깨끗한 clone 재현 체크 (현재 체크아웃 기준 스모크)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/node-v22.17.0-darwin-arm64/bin:$HOME/.local/python312/python/bin:$PATH"

echo "== health =="
curl -sf http://127.0.0.1:11434/api/tags >/dev/null
curl -sf http://127.0.0.1:3001/health >/dev/null || {
  (cd server && node index.js >/tmp/self-heal-api.log 2>&1 &)
  sleep 1
  curl -sf http://127.0.0.1:3001/health >/dev/null
}

echo "== baseline test =="
source .venv/bin/activate
pytest tests/test_region_heal.py -q

echo "== eval 3 cases =="
python scripts/eval_heal_cases.py

echo "REPRO_OK"
