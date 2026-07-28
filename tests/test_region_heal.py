"""지역 선택 화면: 셀렉터 깨지면 한 번만 고치고 다시 클릭."""
from pathlib import Path

import pytest
from playwright.sync_api import expect

from heal import heal_selector, load_selectors

FIXTURE = Path(__file__).resolve().parent.parent / "fixtures" / "region_selection.html"


def test_select_tokyo_region(page):
    """도쿄 클릭. 셀렉터가 틀리면 heal 1회 후 재시도."""
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
