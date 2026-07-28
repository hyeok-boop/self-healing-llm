"""픽스처를 일부러 깨뜨린 뒤 치유되는지 세 가지 케이스로 확인."""
from __future__ import annotations

import json
import sys
import tempfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from heal import FAILURE_API_URL, heal_selector, load_selectors, save_selectors  # noqa: E402

BASELINE = ROOT / "fixtures" / "cases" / "baseline.html"
REPORT_PATH = ROOT / "docs" / "heal-eval-report.json"


@dataclass
class Case:
    name: str
    description: str
    key: str
    broken_selector: str
    intent: str
    mutate: Callable[[str], str]
    expected_text: str


def mutate_testid(html: str) -> str:
    return (
        html.replace('data-testid="region-tokyo"', 'data-testid="region-tokyo-v2"')
        .replace('id="region-tokyo"', 'id="region-tokyo-v2"')
    )


def mutate_id(html: str) -> str:
    # id 변경. testid는 제거하고 data-region만 남겨 복구 단서를 준다.
    return html.replace(
        'id="region-osaka" data-testid="region-osaka"',
        'id="city-osaka" data-region="osaka"',
    )


def mutate_structure(html: str) -> str:
    # class change + wrap: old a.card[href='#tokyo'] no longer matches
    html = html.replace('class="card"', 'class="region-btn"', 1)  # tokyo only first
    return html.replace(
        '<a class="region-btn" id="region-tokyo"',
        '<div class="wrap"><a class="region-btn" id="region-tokyo"',
    ).replace(
        'href="#tokyo">도쿄</a>',
        'href="#tokyo">도쿄</a></div>',
    )


CASES = [
    Case(
        name="testid_rename",
        description="data-testid 변경 (region-tokyo → region-tokyo-v2)",
        key="region_tokyo",
        broken_selector="[data-testid='region-tokyo']",
        intent="도쿄 지역 선택 카드 클릭",
        mutate=mutate_testid,
        expected_text="도쿄",
    ),
    Case(
        name="id_rename",
        description="id 변경 (region-osaka → city-osaka, testid 제거)",
        key="region_osaka",
        broken_selector="#region-osaka",
        intent="오사카 지역 선택 카드 클릭",
        mutate=mutate_id,
        expected_text="오사카",
    ),
    Case(
        name="structure_move",
        description="class/DOM 구조 변경 (card → region-btn + wrap)",
        key="tokyo_card",
        broken_selector="a.card[href='#tokyo']",
        intent="도쿄 지역 선택 카드 클릭",
        mutate=mutate_structure,
        expected_text="도쿄",
    ),
]


def run_case(case: Case) -> dict:
    with tempfile.TemporaryDirectory() as tmp:
        fixture = Path(tmp) / f"{case.name}.html"
        html = case.mutate(BASELINE.read_text(encoding="utf-8"))
        fixture.write_text(html, encoding="utf-8")

        # Reset only this key to the broken selector
        selectors = load_selectors()
        selectors[case.key] = case.broken_selector
        save_selectors(selectors)

        result = {
            "name": case.name,
            "description": case.description,
            "broken_selector": case.broken_selector,
            "healed": False,
            "passed": False,
            "suggested_selector": None,
            "error": None,
        }

        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(fixture.as_uri())

            try:
                page.click(case.broken_selector, timeout=3000)
                # Should not succeed with broken selector
                result["error"] = "broken selector unexpectedly matched"
            except Exception as err:
                healed = heal_selector(
                    page=page,
                    broken_selector=case.broken_selector,
                    intent=case.intent,
                    error=err,
                    key=case.key,
                )
                if healed:
                    result["healed"] = True
                    result["suggested_selector"] = healed
                    try:
                        page.click(healed, timeout=5000)
                        selected = page.locator("#selected")
                        selected.wait_for(state="visible", timeout=3000)
                        if selected.inner_text().strip() == case.expected_text:
                            result["passed"] = True
                        else:
                            result["error"] = f"wrong text: {selected.inner_text()!r}"
                    except Exception as e2:
                        result["error"] = f"retry failed: {e2}"
                else:
                    result["error"] = "heal returned no usable selector"

            browser.close()

        return result


def main() -> int:
    import requests

    try:
        r = requests.get(FAILURE_API_URL.replace("/api/test-failure", "/health"), timeout=5)
        r.raise_for_status()
    except Exception as exc:
        print(f"API not ready at {FAILURE_API_URL}: {exc}")
        print("Start with: ./run.sh api")
        return 1

    # Backup selectors
    backup = load_selectors()
    results = []
    try:
        for case in CASES:
            print(f"\n===== CASE: {case.name} =====")
            results.append(run_case(case))
    finally:
        save_selectors(backup)

    passed = sum(1 for r in results if r["passed"])
    total = len(results)
    rate = round(100.0 * passed / total, 1) if total else 0.0
    report = {
        "total": total,
        "passed": passed,
        "failed": total - passed,
        "success_rate_percent": rate,
        "cases": results,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("\n===== SUMMARY =====")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    print(f"\nWrote {REPORT_PATH}")
    return 0 if passed == total else 2


if __name__ == "__main__":
    raise SystemExit(main())
