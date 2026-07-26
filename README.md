# 자가치유 LLM — Playwright Self-Healing Demo

Playwright 자동화에서 **셀렉터 깨짐**이 나면, 로컬 LLM(Ollama)이 DOM을 분석해 새 셀렉터를 제안·패치하고 테스트를 다시 통과시키는 데모입니다.

> QA 실무에서 흔한 pain point(UI 변경 → 테스트 유지보수 비용)를 로컬 LLM으로 줄이는 흐름을 보여줍니다.

## Demo

https://github.com/user-attachments/assets/PLACEHOLDER

또는 로컬 파일: [`docs/demo/self-heal-demo.mp4`](docs/demo/self-heal-demo.mp4)

**시연 흐름**
1. 정상 테스트 통과
2. 앱의 `data-testid` 의도적 변경 (`region-tokyo` → `region-tokyo-v2`)
3. 재실행 → 실패 감지
4. 로컬 LLM이 DOM 분석 → 새 셀렉터 제안 → `selectors.json` 자동 패치
5. 재실행 → 통과

## Architecture

```
Playwright (pytest)
    │ 실패
    ▼
heal.py  →  Failure API (:3001)  →  Ollama (:11434)
    │                                    │
    └──── suggested_selector ◄───────────┘
              │
              ▼
        selectors.json 갱신 → 재시도
```

## Tech Stack

| 구분 | 기술 |
|------|------|
| 자동화 | Playwright + pytest |
| API | Node.js + Express |
| LLM | Ollama + qwen2.5-coder:7b (로컬) |
| 대상 앱 | Toridoc / Japan (지역 선택 UI) |

## Engineering Decisions

- **실패 분류**: 셀렉터 문제 / 타임아웃 / 실제 버그를 구분. 전부 자동 패치하지 않음
- **신뢰도 게이트**: 제안 셀렉터가 DOM에 실제로 존재할 때만 적용
- **로컬 LLM**: 외부 API 없이 동작 (보안·오프라인)
- **재시도 제한**: 셀렉터당 1회 치유 후 재시도 (무한 루프 방지)

## Quick Start

```bash
# Ollama + 모델
open -a Ollama
ollama pull qwen2.5-coder:7b

# API 서버
./run.sh api

# 데모 (통과 → 깨짐 → 치유 → 재통과)
./demo_heal.sh
```

## Limits & Next

- 현재는 지역 선택 UI 픽스처 기준 데모 (Flutter web 연동은 확장 가능)
- 실패 이력 DB·셀렉터 취약점 통계는 향후 개선 방향
