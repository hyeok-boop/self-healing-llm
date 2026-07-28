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
  return `Playwright 실패 로그와 DOM을 보고, 쓸 CSS 셀렉터를 JSON으로만 답하세요.
앱: 토리닥(여행/지도).

반드시 이 JSON만:
{
  "category": "selector_not_found|timeout|navigation|assertion|network|auth|unknown",
  "summary": "한국어 한 줄",
  "suggested_fix": "한국어로 고치는 방법",
  "suggested_selector": "CSS 셀렉터. 모르면 빈 문자열",
  "confidence": 0.0
}

규칙:
- data-testid 있으면 그걸 우선
- 없으면 #id 또는 [data-region="..."] 같은 속성
- role/텍스트 셀렉터는 쓰지 말 것 (CSS만)
- category가 selector_not_found 또는 셀렉터 관련 timeout이 아니면 suggested_selector는 ""
- 확신이 없으면 suggested_selector는 "" 이고 confidence는 낮게
- id가 바뀐 것 같으면 DOM에 남은 id/data-* 값을 보고 새 CSS를 적을 것

의도: ${intent || 'unknown'}
테스트: ${testName || 'unknown'}
URL: ${url || 'unknown'}
깨진 셀렉터: ${selector || 'unknown'}

에러:
${errorLog || 'none'}

DOM:
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
