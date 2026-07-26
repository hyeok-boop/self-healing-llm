#!/usr/bin/env bash
# Portfolio demo: break Tokyo selector → self-heal → pass
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/node-v22.17.0-darwin-arm64/bin:$HOME/.local/python312/python/bin:$PATH"
source .venv/bin/activate

FIXTURE="fixtures/region_selection.html"
BACKUP="$FIXTURE.bak"

echo "== 1) baseline (should pass) =="
pytest tests/test_region_heal.py -v -s

echo ""
echo "== 2) break app: rename data-testid region-tokyo → region-tokyo-v2 =="
cp "$FIXTURE" "$BACKUP"
sed -i '' "s/data-testid=\"region-tokyo\"/data-testid=\"region-tokyo-v2\"/" "$FIXTURE"
# also keep id renamed so old CSS would fail if someone used #region-tokyo only via testid
sed -i '' "s/id=\"region-tokyo\"/id=\"region-tokyo-v2\"/" "$FIXTURE"

echo "== 3) run again — expect heal then pass =="
pytest tests/test_region_heal.py -v -s

echo ""
echo "== 4) restore fixture =="
mv "$BACKUP" "$FIXTURE"
# reset selector map to original for clean demos
cat > selectors.json <<'EOF'
{
  "region_tokyo": "[data-testid='region-tokyo']",
  "region_osaka": "[data-testid='region-osaka']",
  "selected_result": "#result"
}
EOF

echo "Demo done."
