def test_broken_selector(page):
    """Intentionally fails to verify failure → LLM pipeline."""
    page.goto("https://example.com")
    page.click("#nonexistent-button")
