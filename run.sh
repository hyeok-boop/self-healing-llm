#!/usr/bin/env bash
# 프로젝트 PATH 설정 (Homebrew 없이 설치한 도구들)
export PATH="$HOME/.local/node-v22.17.0-darwin-arm64/bin:$HOME/.local/python312/python/bin:$PATH"
# Prefer project venv python if present
ROOT="$(cd "$(dirname "$0")" && pwd)"

case "${1:-}" in
  api)
    cd "$ROOT/server" && node index.js
    ;;
  test)
    cd "$ROOT"
    source .venv/bin/activate
    pytest tests/ -v -s "${@:2}"
    ;;
  eval)
    cd "$ROOT"
    source .venv/bin/activate
    python scripts/eval_heal_cases.py
    ;;
  demo)
    cd "$ROOT"
    source .venv/bin/activate
    ./demo_heal.sh
    ;;
  ollama-start)
    open -a Ollama
    sleep 2
    curl -s http://127.0.0.1:11434/api/tags | head -c 200
    echo ""
    ;;
  health)
    echo "=== Ollama ==="
    curl -s http://127.0.0.1:11434/api/tags || echo "down"
    echo ""
    echo "=== API Server ==="
    curl -s http://127.0.0.1:3001/health || echo "down"
    echo ""
    ;;
  *)
    echo "Usage: ./run.sh {api|test|eval|demo|ollama-start|health}"
    echo ""
    echo "  ollama-start  Ollama 앱 실행 + API 확인"
    echo "  api           실패로그 API 서버 시작 (:3001)"
    echo "  test          pytest 실행"
    echo "  eval          실패 케이스 3종 치유 성공률 측정"
    echo "  demo          통과→깨짐→치유→재통과 데모"
    echo "  health        Ollama + API 상태 확인"
    ;;
esac
