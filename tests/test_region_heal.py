"""Portfolio demo: region selection smoke + one-shot self-heal on selector rename."""
from pathlib import Path

import pytest
from playwright.sync_api import expect

from heal import heal_selector, load_selectors

FIXTURE = Path(__file__).resolve().parent.parent / "fixtures" / "region_selection.html"


def test_select_tokyo_region(page):
    """Click 도쿄 — heal at most once, then retry.

    Early version retried forever when the model returned a bad selector.
    Now heal_selector enforces a single attempt + DOM existence check.
    """
    page.goto(FIXTURE.as_uri())
    selectors = load_selectors()
    key = "region_tokyo"
    selector = selectors[key]
    intent = "도쿄 지역 선택 카드 클릭"

    try:
        page.click(selector, timeout=5000)
    except Exception as err:
        healed = heal_selector(
            page=page,
            broken_selector=selector,
            intent=intent,
            error=err,
            key=key,
        )
        if not healed:
            raise
        page.click(healed, timeout=5000)

    expect(page.locator("#result")).to_be_visible()
    expect(page.locator("#selected")).to_have_text("도쿄")
