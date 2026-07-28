# 자가치유 LLM

Playwright 테스트가 셀렉터 때문에 깨지면, 로컬 LLM(Ollama)이 DOM을 보고 새 셀렉터를 제안하고 `selectors.json`을 고친 뒤 다시 돌립니다.

토리닥(Japan) 앱의 **지역 선택** UI를 기준으로 한 데모입니다.
모델을 새로 학습(파인튜닝)한 것이 아니라, **로컬에 호스팅한 모델로 추론**만 합니다.

## 데모 영상

https://github.com/hyeok-boop/self-healing-llm/raw/main/docs/demo/self-heal-demo.mp4

1. 정상 통과  
2. `data-testid` 의도적 변경  
3. 실패 → LLM이 DOM 분석 → 셀렉터 패치  
4. 재실행 통과  

## 구조

```
Playwright (pytest)
    │ 실패
    ▼
heal.py  →  Failure API (:3001)  →  Ollama (:11434)
    │                                    │
    └──── suggested_selector ◄───────────┘
              │
              ▼
        selectors.json 갱신 → 재시도(1회)
```

## 치유 성공률 (로컬 측정)

| 케이스 | 변경 내용 | 결과 |
|--------|-----------|------|
| testid_rename | `data-testid` 변경 | 통과 |
| id_rename | `id` 변경 (+ testid 제거) | 통과 |
| structure_move | class/DOM 구조 변경 | 통과 |

**성공률: 3/3 (100%)** — `./run.sh eval` 로 재측정 가능. 리포트: `docs/heal-eval-report.json`

## 왜 이렇게 만들었나

- 초기에 LLM 제안을 그대로 저장했다가, DOM에 없는 셀렉터가 들어가 테스트가 더 망가짐 → **존재 검증** 추가
- 낮은 confidence 제안도 패치되던 문제 → **0.6 미만이면 사람 확인(자동 패치 안 함)**
- 잘못된 제안으로 같은 실패가 반복됨 → **키당 치유 1회**로 제한
- assertion/network 같은 실패까지 고치려 하면 위험함 → **셀렉터 계열만** 자동 패치

## 기술 스택

| 구분 | 기술 |
|------|------|
| 자동화 | Playwright + pytest |
| API | Node.js + Express |
| LLM | Ollama + qwen2.5-coder:7b (로컬 추론) |
| CI | GitHub Actions **self-hosted runner** (M1, localhost Ollama) |

## 빠른 시작

```bash
git clone https://github.com/hyeok-boop/self-healing-llm.git
cd self-healing-llm
chmod +x setup.sh run.sh scripts/*.sh
./setup.sh

# 터미널 1
./run.sh api

# 터미널 2
./run.sh demo    # 한 방 데모
./run.sh eval    # 실패 케이스 3종 + 성공률
```

## CI/CD (self-hosted)

클라우드 runner는 로컬 Ollama(`localhost:11434`)에 접근할 수 없어서, **M1을 self-hosted runner**로 등록합니다.

```bash
# 1) 러너 등록 (최초 1회)
./scripts/setup_runner.sh

# 2) 러너 상시 실행
cd ~/actions-runner && ./run.sh
# 또는: ./svc.sh install && ./svc.sh start
```

워크플로: [`.github/workflows/self-heal.yml`](.github/workflows/self-heal.yml)  
- push / PR / 수동 실행 시 baseline 테스트 + 치유 케이스 3종 평가  
- GitHub → Actions에서 로그·아티팩트(`heal-eval-report`) 확인  

러너 상태: https://github.com/hyeok-boop/self-healing-llm/settings/actions/runners

## 한계 / 다음에 할 일

- 지금은 지역 선택 픽스처 기준 (Flutter web 실앱 연결은 확장 가능)
- 실패 이력을 쌓아 “자주 깨지는 셀렉터” 통계내면 QA 관점에서 더 쓸모 있음
