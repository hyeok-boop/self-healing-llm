const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'qwen2.5-coder:7b';

app.use(cors());
app.use(express.json({ limit: '2mb' }));

function buildPrompt({ errorLog, dom, selector, url, testName, intent }) {
  const domSnippet = typeof dom === 'string' ? dom.slice(0, 8000) : '';
  return `You are a Playwright self-healing assistant for a travel app (Toridoc / Japan).

Goal: when a selector breaks after a UI rename, propose a replacement CSS/Playwright selector from the DOM.

Respond with ONLY valid JSON:
{
  "category": "selector_not_found|timeout|navigation|assertion|network|auth|unknown",
  "summary": "one sentence in Korean",
  "suggested_fix": "concrete fix in Korean",
  "suggested_selector": "a CSS selector that finds the intended element, or empty string",
  "confidence": 0.0
}

Rules for suggested_selector:
- Prefer [data-testid="..."] if present
- Else prefer #id, then button/a text via role is NOT allowed here — CSS only
- Must match an element related to the user intent / broken selector
- If unsure, return empty string

User intent: ${intent || 'unknown'}
Test: ${testName || 'unknown'}
URL: ${url || 'unknown'}
Broken selector: ${selector || 'unknown'}

Error:
${errorLog || 'none'}

DOM snippet:
${domSnippet}`;
}

async function classifyWithOllama(payload) {
  const response = await fetch(`${OLLAMA_URL}/api/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: OLLAMA_MODEL,
      prompt: buildPrompt(payload),
      stream: false,
      options: { temperature: 0.1 },
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Ollama error ${response.status}: ${text}`);
  }

  const data = await response.json();
  const raw = data.response || '';

  try {
    const jsonMatch = raw.match(/\{[\s\S]*\}/);
    return jsonMatch
      ? JSON.parse(jsonMatch[0])
      : { category: 'unknown', summary: raw, suggested_fix: '', suggested_selector: '', confidence: 0.3 };
  } catch {
    return { category: 'unknown', summary: raw.slice(0, 500), suggested_fix: '', suggested_selector: '', confidence: 0.2 };
  }
}

app.get('/health', async (_req, res) => {
  try {
    const r = await fetch(`${OLLAMA_URL}/api/tags`);
    if (!r.ok) throw new Error('Ollama unreachable');
    res.json({ ok: true, ollama: OLLAMA_URL, model: OLLAMA_MODEL });
  } catch (err) {
    res.status(503).json({ ok: false, error: err.message });
  }
});

app.post('/api/test-failure', async (req, res) => {
  const { errorLog, dom, selector, url, testName, intent } = req.body || {};

  if (!errorLog && !dom) {
    return res.status(400).json({ error: 'errorLog or dom required' });
  }

  try {
    const classification = await classifyWithOllama({
      errorLog, dom, selector, url, testName, intent,
    });
    res.json({ ok: true, classification, model: OLLAMA_MODEL });
  } catch (err) {
    res.status(502).json({ ok: false, error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Failure log API listening on http://localhost:${PORT}`);
  console.log(`Ollama: ${OLLAMA_URL} | model: ${OLLAMA_MODEL}`);
});
