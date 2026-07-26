import os
import json
import requests
import pytest
from playwright.sync_api import Page

FAILURE_API_URL = os.getenv("FAILURE_API_URL", "http://127.0.0.1:3001/api/test-failure")


def classify_failure(page: Page, error: Exception, test_name: str) -> dict | None:
    """Send failure context to local API server → Ollama classification."""
    try:
        dom = page.content()
        url = page.url
    except Exception:
        dom = ""
        url = ""

    payload = {
        "errorLog": str(error),
        "dom": dom,
        "selector": getattr(error, "selector", None),
        "url": url,
        "testName": test_name,
    }

    try:
        resp = requests.post(FAILURE_API_URL, json=payload, timeout=120)
        resp.raise_for_status()
        return resp.json()
    except requests.RequestException as exc:
        print(f"[classify_failure] API call failed: {exc}")
        return None


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()

    if report.when != "call" or not report.failed:
        return

    page = item.funcargs.get("page")
    if page is None:
        return

    result = classify_failure(page, call.excinfo.value, item.name)
    if result:
        print("\n=== LLM Failure Classification ===")
        print(json.dumps(result, indent=2, ensure_ascii=False))


@pytest.fixture
def page():
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        pg = context.new_page()
        yield pg
        browser.close()
