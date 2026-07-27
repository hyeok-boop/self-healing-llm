#!/usr/bin/env bash
# Self-hosted runner 등록 도우미 (M1 로컬)
# 사전: gh auth login 완료, Ollama 실행 중
set -euo pipefail

REPO="${REPO:-hyeok-boop/self-healing-llm}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"

echo "=== GitHub self-hosted runner setup ==="
echo "Repo: $REPO"
echo "Install dir: $RUNNER_DIR"
echo ""

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI가 필요합니다. https://cli.github.com/"
  exit 1
fi

TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token)
echo "Registration token acquired (expires ~1 hour)."

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ ! -f ./config.sh ]; then
  echo "Downloading actions runner (macOS arm64)..."
  curl -fsSL -o actions-runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-osx-arm64-2.322.0.tar.gz"
  tar xzf actions-runner.tar.gz
fi

if [ ! -f .runner ]; then
  ./config.sh --url "https://github.com/$REPO" --token "$TOKEN" --name "$(hostname)-m1" --unattended --labels self-hosted,macOS,ARM64
fi

echo ""
echo "등록 완료. 러너 시작:"
echo "  cd $RUNNER_DIR && ./run.sh"
echo ""
echo "백그라운드 상시 실행(선택):"
echo "  cd $RUNNER_DIR && ./svc.sh install && ./svc.sh start"
echo ""
echo "GitHub에서 확인:"
echo "  https://github.com/$REPO/settings/actions/runners"
