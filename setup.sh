#!/usr/bin/env bash
# Clone 후 한 번에 환경 맞추기 (macOS arm64 기준)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

have() { command -v "$1" >/dev/null 2>&1; }

echo "=== 1) Ollama ==="
if [ ! -x "/Applications/Ollama.app/Contents/Resources/ollama" ]; then
  echo "Ollama 앱이 없습니다. https://ollama.com/download 에서 설치 후 다시 실행하세요."
  exit 1
fi
open -a Ollama || true
sleep 2
if ! curl -sf http://127.0.0.1:11434/api/tags >/dev/null; then
  /Applications/Ollama.app/Contents/Resources/ollama serve >/tmp/ollama-serve.log 2>&1 &
  sleep 2
fi
/Applications/Ollama.app/Contents/Resources/ollama pull qwen2.5-coder:7b

echo "=== 2) Node.js ==="
if have node && have npm; then
  NODE_OK=1
else
  NODE_OK=0
  if [ ! -d "$HOME/.local/node-v22.17.0-darwin-arm64" ]; then
    curl -fsSL "https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz" -o /tmp/node.tar.gz
    mkdir -p "$HOME/.local"
    tar -xzf /tmp/node.tar.gz -C "$HOME/.local"
  fi
  export PATH="$HOME/.local/node-v22.17.0-darwin-arm64/bin:$PATH"
fi
node --version
npm --version

echo "=== 3) Python + Playwright ==="
if have python3 && python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3,10) else 1)'; then
  PY=python3
else
  if [ ! -d "$HOME/.local/python312" ]; then
    curl -fsSL "https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.12.7+20241016-aarch64-apple-darwin-install_only.tar.gz" -o /tmp/python312.tar.gz
    mkdir -p "$HOME/.local/python312"
    tar -xzf /tmp/python312.tar.gz -C "$HOME/.local/python312"
  fi
  export PATH="$HOME/.local/python312/python/bin:$PATH"
  PY=python3
fi
$PY -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
playwright install chromium

echo "=== 4) API server deps ==="
(cd server && npm install)

echo ""
echo "=== 완료 ==="
echo "터미널 1: ./run.sh api"
echo "터미널 2: ./run.sh demo     # 또는 ./run.sh eval"
echo ""
echo "CI(self-hosted runner) 등록: ./scripts/setup_runner.sh"
