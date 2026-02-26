# {{PROJECT_NAME}}

> {{DESCRIPTION}}
> 시작일: {{DATE}}

---

## 세션 시작 시

```
1. EXPERIMENT_LOG.md 마지막 20줄 확인 → 최근 작업 파악
2. CONCEPT.md 읽기 → 연구 목표 파악
3. 실험 예정이면 ../_knowledge/lessons_learned.md 확인
```

---

## 주제 키워드

<!-- Claude가 관련 논문 검색에 사용 -->

---

## 지식 저장 위치

| 발견한 것 | 저장 위치 |
|----------|----------|
| 새 논문 | `../_knowledge/papers/{Author}_{Year}_{Keyword}.md` |
| 이 프로젝트 아이디어 | `./CONCEPT.md` |
| 실험 결과 | `./EXPERIMENT_LOG.md` |
| 프로젝트 간 교훈 | `../_knowledge/lessons_learned.md` |

---

## 실험 네이밍 규칙 (절대 규칙)

**모든 실험에는 프로젝트명 `{{PROJECT_NAME}}`을 반드시 포함한다.**

서버든 로컬이든, 실험을 제출/실행할 때 아래 규칙을 따릅니다:

| 대상 | 규칙 | 예시 |
|------|------|------|
| SLURM job name | `--job-name={{PROJECT_NAME}}_실험명` | `--job-name={{PROJECT_NAME}}_baseline_v1` |
| W&B | `project="{{PROJECT_NAME}}"`, run name에도 포함 | `wandb.init(project="{{PROJECT_NAME}}", name="baseline_v1")` |
| 출력 디렉토리 | 프로젝트 내부 경로 사용 | `~/projects/{{PROJECT_NAME}}/results/실험명/` |
| 로그 파일 | `{{PROJECT_NAME}}_실험명.log` | `{{PROJECT_NAME}}_baseline_v1.log` |
| tmux/screen 세션 | `{{PROJECT_NAME}}_` 접두사 | `tmux new -s {{PROJECT_NAME}}_train` |

### Claude 행동 규칙

- 실험 스크립트 작성 시 위 네이밍을 **자동 적용**
- 사용자가 프로젝트명 없이 실험을 제출하려 하면 **경고 후 수정 제안**
- EXPERIMENT_LOG.md 기록 시 네이밍 준수 여부 확인
- `squeue`, `wandb` 등에서 **이 프로젝트 실험만 필터링**하여 보고:
  - `squeue -u $USER --name={{PROJECT_NAME}}*`
  - 다른 프로젝트의 job은 무시 (프로젝트 격리 원칙)

---

## Cross-Review

> 전역 CLAUDE.md의 Cross-Review 규칙을 따릅니다.

---

## 서버 경로

- 맥북: `~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/{{PROJECT_NAME}}/`
- 서버: `~/projects/{{PROJECT_NAME}}/`
- 동기화: `sync_to soda` / `fetch_from soda`
