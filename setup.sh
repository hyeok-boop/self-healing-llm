#!/usr/bin/env bash
# M1 초기 환경 설정 스크립트
# Homebrew/Xcode 없이도 동작하는 경로 포함 (이미 설치된 경우 스킵)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "=== 0단계 (선택): Xcode CLI Tools + Homebrew ==="
echo "git 등 시스템 도구가 필요하면 터미널에서 직접 실행:"
echo "  xcode-select --install"
echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

echo "=== 1단계: Ollama ==="
if [ ! -d "/Applications/Ollama.app" ]; then
  curl -fsSL https://ollama.com/download/Ollama-darwin.zip -o /tmp/Ollama-darwin.zip
  unzip -qo /tmp/Ollama-darwin.zip -d /tmp
  cp -R /tmp/Ollama.app /Applications/
fi
open -a Ollama
sleep 3
/Applications/Ollama.app/Contents/Resources/ollama pull qwen2.5-coder:7b

echo "=== 2단계: Node.js (standalone) ==="
if [ ! -d "$HOME/.local/node-v22.17.0-darwin-arm64" ]; then
  curl -fsSL "https://nodejs.org/dist/v22.17.0/node-v22.17.0-darwin-arm64.tar.gz" -o /tmp/node.tar.gz
  mkdir -p "$HOME/.local"
  tar -xzf /tmp/node.tar.gz -C "$HOME/.local"
fi
export PATH="$HOME/.local/node-v22.17.0-darwin-arm64/bin:$PATH"

echo "=== 3단계: Python + Playwright ==="
if [ ! -d "$HOME/.local/python312" ]; then
  curl -fsSL "https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.12.7+20241016-aarch64-apple-darwin-install_only.tar.gz" -o /tmp/python312.tar.gz
  mkdir -p "$HOME/.local/python312"
  tar -xzf /tmp/python312.tar.gz -C "$HOME/.local/python312"
fi
export PATH="$HOME/.local/python312/python/bin:$PATH"
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
playwright install chromium

echo "=== 4단계: Node API 서버 ==="
cd server && npm install && cd ..

echo "=== 완료 ==="
echo "터미널 1: ./run.sh api"
echo "터미널 2: ./run.sh test"
