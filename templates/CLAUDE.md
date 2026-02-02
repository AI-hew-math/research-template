# {{PROJECT_NAME}}

> {{DESCRIPTION}}

---

## 세션 시작 시 Claude 행동

### 1단계: 현재 상태 파악
```
읽을 파일:
- 이 파일 (CLAUDE.md)
- CONCEPT.md → 연구 아이디어
- EXPERIMENT_LOG.md 하단 → 최근 실험
```

### 2단계: 공유 지식 확인
```
이 프로젝트 관련 주제의 MOC 확인:
- ../_knowledge/MOCs/ 에서 관련 MOC 검색
- 있으면 읽고 관련 자료 파악
```

### 3단계: 현재 단계 판단 후 다음 액션 제안

---

## 지식 베이스 연동

### 이 프로젝트 관련 MOC
<!-- Claude가 자동으로 업데이트 -->
- `../_knowledge/MOCs/MOC_xxx.md`

### 참조할 공유 지식
```
../_knowledge/
├── concepts/    # 관련 개념
├── papers/      # 관련 논문
├── methods/     # 사용할 기법
└── lessons_learned.md  # 과거 교훈
```

### 지식 저장 규칙
| 발견한 것 | 저장 위치 |
|----------|----------|
| 새 논문 | `../_knowledge/papers/` |
| 새 개념 | `../_knowledge/concepts/` |
| 재사용 기법 | `../_knowledge/methods/` |
| 실패/성공 교훈 | `../_knowledge/lessons_learned.md` |
| 프로젝트 실험 결과 | `./EXPERIMENT_LOG.md` |

---

## 단계별 행동

### 아이디어 정립
```
1. 관련 MOC 확인 → 기존 지식 파악
2. WebSearch로 추가 조사
3. CONCEPT.md에 아이디어 정리
4. 새 개념 → _knowledge/concepts/에 저장
```

### 문헌 조사
```
1. 관련 MOC의 논문 목록 확인
2. 새 논문 발견 → _knowledge/papers/에 저장
3. MOC에 링크 추가
4. CONCEPT.md에 인사이트 반영
```

### 구현
```
1. _knowledge/methods/ 에서 재사용 가능한 기법 확인
2. src/에 코드 작성
3. 새로운 재사용 기법 발견 → _knowledge/methods/에 저장
```

### 실험
```
1. _knowledge/lessons_learned.md 확인 (과거 실수 방지)
2. 서버 확인 → sbatch 생성 → 제출
3. 결과 → EXPERIMENT_LOG.md에 기록
4. 중요 교훈 → _knowledge/lessons_learned.md에 추가
```

---

## 이 프로젝트 정보

- **시작일**: {{DATE}}
- **맥북 경로**: `~/...Claude_projects/{{PROJECT_NAME}}/`
- **서버 경로**: `~/projects/{{PROJECT_NAME}}/`

---

## 컨텍스트 메모

<!-- 프로젝트 진행하면서 Claude가 기억해야 할 것들 -->

