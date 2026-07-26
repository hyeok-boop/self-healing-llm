#!/usr/bin/env bash
# 프로젝트 PATH 설정 (Homebrew 없이 설치한 도구들)
export PATH="$HOME/.local/node-v22.17.0-darwin-arm64/bin:$HOME/.local/python312/python/bin:$PATH"
export OLLAMA_BIN="/Applications/Ollama.app/Contents/Resources/ollama"

case "${1:-}" in
  api)
    cd "$(dirname "$0")/server" && node index.js
    ;;
  test)
    cd "$(dirname "$0")"
    source .venv/bin/activate
    pytest tests/ -v -s "${@:2}"
    ;;
  ollama-start)
    open -a Ollama
    sleep 2
    curl -s http://127.0.0.1:11434/api/tags | head -c 200
    echo ""
    ;;
  health)
    echo "=== Ollama ==="
    curl -s http://127.0.0.1:11434/api/tags
    echo ""
    echo "=== API Server ==="
    curl -s http://127.0.0.1:3001/health
    echo ""
    ;;
  *)
    echo "Usage: ./run.sh {api|test|ollama-start|health}"
    echo ""
    echo "  ollama-start  Ollama 앱 실행 + API 확인"
    echo "  api           실패로그 API 서버 시작 (:3001)"
    echo "  test          pytest 실행 (실패 시 LLM 분류)"
    echo "  health        Ollama + API 상태 확인"
    ;;
esac
