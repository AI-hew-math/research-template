# {{PROJECT_NAME}}

> {{DESCRIPTION}}
> 시작일: {{DATE}}

---

## 🔴 세션 시작 시 필수 행동

### Step 1: 지식 베이스 확인 (생략 불가)

```
1. ../_knowledge/INDEX.md 읽기
2. 이 프로젝트 주제 키워드로 "키워드 → MOC 매핑" 검색
3. 결과를 사용자에게 알리기:
   - "기존 관련 자료: 논문 N개, 프로젝트 M개"
   - 또는 "새로운 주제입니다"
```

### Step 2: 프로젝트 상태 파악

```
1. CONCEPT.md 읽기 → 연구 아이디어 확인
2. EXPERIMENT_LOG.md 하단 → 최근 실험 확인
3. 현재 단계 판단:
   - CONCEPT.md 비어있음 → 아이디어 정립 단계
   - 실험 진행 중 → 실험 단계
```

### Step 3: 다음 액션 제안

---

## 이 프로젝트 정보

- **주제 키워드**: <!-- Claude가 INDEX.md 검색에 사용할 키워드 -->
- **관련 MOC**: <!-- 연결된 MOC 파일 -->
- **관련 프로젝트**: <!-- 비슷한 주제의 다른 프로젝트 -->

---

## 지식 베이스 연동

### 저장 위치 규칙

| 발견한 것 | 저장 위치 |
|----------|----------|
| 새 논문 | `../_knowledge/papers/` + INDEX.md 업데이트 |
| 일반 개념 (재사용 가능) | `../_knowledge/concepts/` + INDEX.md 업데이트 |
| 이 프로젝트만의 아이디어 | `./CONCEPT.md` |
| 재사용 기법 | `../_knowledge/methods/` |
| 실험 교훈 | `../_knowledge/lessons_learned.md` |
| 실험 결과 | `./EXPERIMENT_LOG.md` |

### CONCEPT.md vs concepts/ 구분

- **CONCEPT.md**: "blur kernel과 depth의 비선형 관계를 MLP로 학습" (이 프로젝트 전용)
- **concepts/**: "Depth from Defocus의 광학 원리" (다른 프로젝트도 참조 가능)

---

## 단계별 행동

### 아이디어 정립
```
1. INDEX.md에서 관련 기존 지식 확인
2. 기존 지식 있으면 참고하여 차별점 파악
3. WebSearch로 추가 조사
4. CONCEPT.md에 아이디어 정리
5. 새 일반 개념 → _knowledge/concepts/에 저장
6. INDEX.md "프로젝트 → 주제 매핑"에 이 프로젝트 추가
```

### 문헌 조사
```
1. INDEX.md에서 기존 논문 확인 (중복 방지)
2. 새 논문 발견 → _knowledge/papers/에 저장
3. INDEX.md "최근 업데이트" 추가
4. 논문 2개 이상 → MOC 생성 고려
5. CONCEPT.md에 인사이트 반영
```

### 구현
```
1. _knowledge/methods/ 에서 재사용 가능한 기법 확인
2. src/에 코드 작성
3. 새로운 재사용 기법 → _knowledge/methods/에 저장
```

### 실험
```
1. _knowledge/lessons_learned.md 확인 (과거 실수 방지)
2. 관련 교훈 있으면 사용자에게 알리기
3. 서버 상태 확인 (soda → vegi → potato)
4. sbatch 생성 → 제출 → Slack 알림 설정
5. 결과 → EXPERIMENT_LOG.md에 기록
6. 중요 교훈 → _knowledge/lessons_learned.md에 추가
```

---

## 서버 경로

- 맥북: `~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/{{PROJECT_NAME}}/`
- 서버: `~/projects/{{PROJECT_NAME}}/`
- 동기화: `sync_to soda` / `fetch_from soda`

---

## 컨텍스트 메모

<!-- 프로젝트 진행하면서 중요한 컨텍스트 추가 -->
