"""Load/save selectors.json and ask local LLM API for a healed selector."""
from __future__ import annotations

import json
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent
SELECTORS_PATH = ROOT / "selectors.json"
FAILURE_API_URL = "http://127.0.0.1:3001/api/test-failure"


def load_selectors() -> dict:
    return json.loads(SELECTORS_PATH.read_text(encoding="utf-8"))


def save_selectors(data: dict) -> None:
    SELECTORS_PATH.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def heal_selector(
    *,
    page,
    broken_selector: str,
    intent: str,
    error: Exception,
    key: str,
) -> str | None:
    """Ask LLM for a new selector, verify it exists, persist to selectors.json."""
    try:
        dom = page.content()
        url = page.url
    except Exception:
        dom = ""
        url = ""

    payload = {
        "errorLog": str(error),
        "dom": dom,
        "selector": broken_selector,
        "url": url,
        "testName": key,
        "intent": intent,
    }

    resp = requests.post(FAILURE_API_URL, json=payload, timeout=120)
    resp.raise_for_status()
    body = resp.json()
    classification = body.get("classification") or {}
    suggested = (classification.get("suggested_selector") or "").strip()

    print("\n=== Self-heal suggestion ===")
    print(json.dumps(classification, indent=2, ensure_ascii=False))

    if not suggested:
        return None

    # Verify the suggested selector finds something on the current page
    if page.locator(suggested).count() == 0:
        print(f"[heal] suggested selector not found on page: {suggested}")
        return None

    selectors = load_selectors()
    selectors[key] = suggested
    save_selectors(selectors)
    print(f"[heal] updated selectors.json[{key!r}] -> {suggested}")
    return suggested
