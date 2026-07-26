#!/usr/bin/env bash
# 포트폴리오 녹화용 — 터미널에서 직접 실행
# 사용법:
#   ./clip.sh 1
#   ./clip.sh 2
#   ./clip.sh 3
#   ./clip.sh 4
#   ./clip.sh reset   # 픽스처/셀렉터 원복
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$HOME/.local/node-v22.17.0-darwin-arm64/bin:$HOME/.local/python312/python/bin:$PATH"

ensure_api() {
  if ! curl -s http://127.0.0.1:3001/health >/dev/null 2>&1; then
    echo "(API 서버 시작 중...)"
    (cd server && node index.js > /tmp/failure-api.log 2>&1 &)
    sleep 1
  fi
}

reset_state() {
  cat > selectors.json <<'EOF'
{
  "region_tokyo": "[data-testid='region-tokyo']",
  "region_osaka": "[data-testid='region-osaka']",
  "selected_result": "#result"
}
EOF
  sed -i '' 's/data-testid="region-tokyo-v2"/data-testid="region-tokyo"/g' fixtures/region_selection.html
  sed -i '' 's/id="region-tokyo-v2"/id="region-tokyo"/g' fixtures/region_selection.html
  echo "원복 완료: selectors.json + fixture → region-tokyo"
}

clip1() {
  reset_state
  ensure_api
  source .venv/bin/activate
  clear
  echo "=== CLIP 1: baseline pass ==="
  echo
  echo "selectors.json:"
  cat selectors.json
  echo
  pytest tests/test_region_heal.py -v -s
  echo
  echo "=== CLIP 1 DONE ==="
}

clip2() {
  clear
  echo "=== CLIP 2: break app selector ==="
  echo
  echo "--- BEFORE ---"
  grep -n 'data-testid\|id="region' fixtures/region_selection.html
  echo
  sed -i '' 's/data-testid="region-tokyo"/data-testid="region-tokyo-v2"/' fixtures/region_selection.html
  sed -i '' 's/id="region-tokyo"/id="region-tokyo-v2"/' fixtures/region_selection.html
  echo "--- AFTER ---"
  grep -n 'data-testid\|id="region' fixtures/region_selection.html
  echo
  echo "=== CLIP 2 DONE — region-tokyo → region-tokyo-v2 ==="
}

clip3() {
  # 옛 셀렉터 유지 (치유 경로 유도)
  cat > selectors.json <<'EOF'
{
  "region_tokyo": "[data-testid='region-tokyo']",
  "region_osaka": "[data-testid='region-osaka']",
  "selected_result": "#result"
}
EOF
  ensure_api
  source .venv/bin/activate
  clear
  echo "=== CLIP 3: fail → LLM heal ==="
  echo
  echo "현재 selectors.json (아직 옛 셀렉터):"
  cat selectors.json
  echo
  echo "앱은 이미 region-tokyo-v2로 변경된 상태"
  echo
  pytest tests/test_region_heal.py -v -s
  echo
  echo "치유 후 selectors.json:"
  cat selectors.json
  echo
  echo "=== CLIP 3 DONE ==="
}

clip4() {
  ensure_api
  source .venv/bin/activate
  clear
  echo "=== CLIP 4: retest after heal ==="
  echo
  echo "치유된 selectors.json:"
  cat selectors.json
  echo
  pytest tests/test_region_heal.py -v -s
  echo
  echo "=== CLIP 4 DONE — 자가치유 후 재통과 ==="
}

case "${1:-}" in
  1) clip1 ;;
  2) clip2 ;;
  3) clip3 ;;
  4) clip4 ;;
  reset) reset_state ;;
  *)
    echo "사용법: ./clip.sh {1|2|3|4|reset}"
    echo ""
    echo "  1      정상 통과"
    echo "  2      앱 셀렉터 변경 (break)"
    echo "  3      실패 → LLM 자가치유"
    echo "  4      치유 후 재통과"
    echo "  reset  처음부터 다시 (원복)"
    exit 1
    ;;
esac
