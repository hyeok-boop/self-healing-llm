# 자가치유 LLM

Playwright 테스트가 셀렉터 때문에 실패하면, 맥에 띄운 Ollama가 DOM을 보고 새 셀렉터를 제안합니다.
맞으면 `selectors.json`에 저장하고 한 번 더 돌려 봅니다.

대상은 토리닥(Japan) 앱의 지역 선택 화면입니다.
모델을 따로 학습시킨 게 아닙니다. 이미 있는 모델을 로컬에서만 돌립니다.

## 데모

https://github.com/hyeok-boop/self-healing-llm/raw/main/docs/demo/self-heal-demo.mp4

1. 테스트 통과
2. `data-testid`만 바꿔서 깨뜨림
3. 실패 → Ollama가 DOM 보고 셀렉터 제안 → 저장
4. 다시 돌려서 통과

## 흐름

```
Playwright (pytest)
    │ 실패
    ▼
heal.py  →  API (:3001)  →  Ollama (:11434)
    │                              │
    └──── 새 셀렉터 ◄──────────────┘
              │
              ▼
        selectors.json 저장 → 재시도 1회
```

## 측정 결과

`./run.sh eval` 기준 (로컬):

| 케이스 | 무엇을 바꿨나 | 결과 |
|--------|----------------|------|
| testid_rename | data-testid 이름 변경 | 통과 |
| id_rename | id 변경, testid 제거 | 통과 |
| structure_move | class / DOM 구조 변경 | 통과 |

3/3 통과. 자세한 값은 `docs/heal-eval-report.json`.

## 구현하면서 막혔던 것

- LLM이 낸 셀렉터를 그냥 저장했더니, 페이지에 없는 값이 들어가서 더 망가짐 → 저장 전에 DOM에 있는지 확인
- confidence가 낮은 제안도 들어감 → 0.6 미만이면 자동 저장 안 함
- 잘못된 제안으로 같은 실패가 반복됨 → 셀렉터 키마다 치유는 1번만
- 셀렉터 문제가 아닌 실패(assertion 등)까지 고치려 하면 위험해서, 셀렉터 관련만 자동 처리

## 스택

| | |
|--|--|
| 테스트 | Playwright, pytest |
| API | Node.js, Express |
| LLM | Ollama, qwen2.5-coder:7b (로컬) |
| CI | GitHub Actions self-hosted runner (이 맥) |

## 실행

```bash
git clone https://github.com/hyeok-boop/self-healing-llm.git
cd self-healing-llm
chmod +x setup.sh run.sh scripts/*.sh
./setup.sh

# 터미널 1
./run.sh api

# 터미널 2
./run.sh demo
./run.sh eval
```

## CI

Actions 클라우드 러너는 이 맥의 Ollama(`localhost:11434`)에 못 붙습니다.
그래서 이 맥을 self-hosted runner로 씁니다.

```bash
./scripts/setup_runner.sh
cd ~/actions-runner && ./run.sh
```

- 워크플로: `.github/workflows/self-heal.yml`
- 러너: https://github.com/hyeok-boop/self-healing-llm/settings/actions/runners
- 실행 로그: https://github.com/hyeok-boop/self-healing-llm/actions

## 아직

- 지금은 HTML 픽스처 기준. Flutter web 실앱에 붙이는 건 다음 단계
- 실패 로그를 쌓아서 자주 깨지는 셀렉터를 보는 건 나중에
