# {{PROJECT_NAME}}

> {{DESCRIPTION}}

---

## 세션 시작 시 자동 행동

**Claude는 이 프로젝트 폴더에서 세션이 시작되면:**

1. 아래 파일들을 읽어 현재 상태 파악:
   - `CONCEPT.md` → 연구 아이디어 이해
   - `survey/reading_list.md` → 논문 서베이 진행상황
   - `EXPERIMENT_LOG.md` 하단 → 최근 실험 현황

2. 현재 단계 자동 판단:
   - CONCEPT.md가 비어있음 → **아이디어 정립 단계**
   - 논문 서베이 중 → **문헌 조사 단계**
   - 코드 작성 중 → **구현 단계**
   - 실험 진행 중 → **실험 단계**

3. **사용자에게 현재 상태 요약 + 다음 액션 제안**

---

## 단계별 Claude 행동

### 아이디어 정립 단계
사용자가 아이디어를 말하면:
- 관련 키워드로 논문 검색 (WebSearch)
- 기존 연구가 있는지 파악
- `CONCEPT.md`에 아이디어 정리
- `survey/reading_list.md`에 관련 논문 추가

**자동 제안**: "관련 논문을 조사해볼까요?" / "아이디어를 CONCEPT.md에 정리할까요?"

### 문헌 조사 단계
- 논문 링크 받으면 → `survey/notes/`에 노트 생성
- 조사 결과 → `reading_list.md` 업데이트
- 핵심 인사이트 → `CONCEPT.md`에 반영

**자동 제안**: "다음으로 읽을 논문이 X개 있어요. [논문명] 분석할까요?"

### 구현 단계
- 코드는 `src/` 구조에 맞게 작성
- 설정 파일 → `experiments/configs/`
- 실험 스크립트 → `experiments/scripts/`

**자동 제안**: "baseline 먼저 구현할까요?" / "테스트 코드 작성할까요?"

### 실험 단계
- 서버 상태 자동 확인 (soda → vegi → potato)
- sbatch 스크립트 생성 + Slack 알림 설정
- 결과 나오면 → `EXPERIMENT_LOG.md`에 기록

**자동 제안**: "실험 결과가 있네요. 분석해볼까요?" / "다음 ablation은 뭘로 할까요?"

---

## 사용자가 할 일

**그냥 자연스럽게 대화하면 됩니다:**

```
"연구 시작하자"
"이 논문 봐줘: [링크]"
"baseline 구현해줘"
"실험 돌려줘"
"결과 어때?"
```

Claude가 알아서:
- 현재 상태에 맞는 행동 수행
- 다음 단계 제안
- 필요한 파일 업데이트

---

## 파일 역할

| 파일 | 용도 | Claude 자동 업데이트 |
|------|------|---------------------|
| `CONCEPT.md` | 연구 아이디어 | 인사이트 발견 시 |
| `EXPERIMENT_LOG.md` | 실험 결과 | 실험 완료 시 |
| `survey/reading_list.md` | 논문 목록 | 논문 발견/읽을 때 |
| `survey/notes/*.md` | 논문 노트 | 논문 분석 시 |

---

## 서버 설정

- 맥북: `~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/{{PROJECT_NAME}}/`
- 서버: `~/projects/{{PROJECT_NAME}}/`
- 동기화: `sync_to soda` / `fetch_from soda`

---

## 컨텍스트 메모

<!-- 프로젝트 진행하면서 Claude가 기억해야 할 것들 추가 -->

