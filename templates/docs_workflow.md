# Research Workflow with Claude

Claude Code를 활용한 연구 워크플로우 가이드입니다.

---

## Phase 0: 프로젝트 시작

### 새 프로젝트 생성
```bash
./create_project.sh "ProjectName" "연구 주제 설명"
cd ../ProjectName
```

### Claude에게 컨텍스트 제공
```
"이 프로젝트는 [주제]에 관한 연구야.
CONCEPT.md를 읽고 이해해줘."
```

---

## Phase 1: 아이디어 정립 및 문헌 조사

### Step 1.1: 관련 연구 조사
```
사용자: "[주제] 관련 최신 논문들 조사해줘"

Claude 행동:
1. WebSearch로 관련 논문 검색
2. survey/reading_list.md에 발견한 논문 추가
3. 핵심 논문 식별 및 표시
```

### Step 1.2: 핵심 논문 분석
```
사용자: "이 논문 읽고 정리해줘: [arxiv/paper 링크]"

Claude 행동:
1. 논문 내용 분석
2. survey/notes/에 논문 노트 생성
3. reading_list.md 상태 업데이트 (📖→✅)
4. CONCEPT.md에 관련 인사이트 추가
```

### Step 1.3: 아이디어 구체화
```
사용자: "조사한 내용 바탕으로 CONCEPT.md 업데이트해줘"

Claude 행동:
1. 기존 연구와의 차별점 정리
2. 연구 가설 구체화
3. 실험 계획 초안 작성
```

---

## Phase 2: Baseline 구현

### Step 2.1: 환경 설정
```
사용자: "프로젝트 환경 설정해줘"

Claude 행동:
1. requirements.txt 생성
2. docs/setup.md 작성
3. 서버에 환경 설치 명령 안내
```

### Step 2.2: 데이터 준비
```
사용자: "[데이터셋] 로딩 코드 작성해줘"

Claude 행동:
1. src/data/에 데이터 로더 구현
2. 데이터 다운로드/전처리 스크립트 작성
```

### Step 2.3: Baseline 구현
```
사용자: "[논문명] baseline 구현해줘"

Claude 행동:
1. src/models/에 모델 구현
2. src/training/에 학습 코드 작성
3. experiments/configs/baseline.yaml 생성
```

### Step 2.4: Baseline 실험
```
사용자: "baseline 실험 제출해줘"

Claude 행동:
1. 서버 상태 확인 (soda, vegi, potato)
2. experiments/scripts/에 sbatch 스크립트 생성
3. Slack 알림 설정
4. 코드 동기화 및 제출
```

---

## Phase 3: 제안 방법 구현

### Step 3.1: 핵심 모듈 구현
```
사용자: "CONCEPT.md의 제안 방법 구현해줘"

Claude 행동:
1. src/models/에 제안 모델 구현
2. 단위 테스트 작성
3. 노트북에서 프로토타이핑
```

### Step 3.2: 통합 및 테스트
```
사용자: "학습 파이프라인에 통합해줘"

Claude 행동:
1. src/training/ 수정
2. experiments/configs/proposed.yaml 생성
3. 로컬/작은 데이터로 테스트
```

---

## Phase 4: 실험 및 분석

### Step 4.1: 메인 실험
```
사용자: "메인 실험 제출해줘"

Claude 행동:
1. 실험 설정 확인
2. sbatch 스크립트 생성
3. Slack 3단계 알림 설정
4. 제출 후 EXPERIMENT_LOG.md에 기록 시작
```

### Step 4.2: 결과 분석
```
사용자: "실험 결과 분석해줘"

Claude 행동:
1. 결과 로그 파싱
2. EXPERIMENT_LOG.md에 결과 기록
3. results/figures/에 시각화 생성
4. 다음 실험 제안
```

### Step 4.3: Ablation Study
```
사용자: "ablation study 설계해줘"

Claude 행동:
1. 테스트할 컴포넌트 식별
2. experiments/configs/ablation/ 생성
3. 배치 실험 스크립트 작성
```

---

## Phase 5: 논문 작성

### Step 5.1: 결과 정리
```
사용자: "논문용 결과 테이블 만들어줘"

Claude 행동:
1. EXPERIMENT_LOG.md에서 결과 추출
2. LaTeX 테이블 생성
3. results/tables/에 저장
```

### Step 5.2: Figure 생성
```
사용자: "논문용 figure 만들어줘"

Claude 행동:
1. 고품질 시각화 생성
2. results/figures/paper/에 저장
3. 적절한 포맷(PDF, PNG) 제공
```

---

## 유용한 명령어 모음

### 논문 서베이
```
"[주제] 관련 최신 논문 조사해줘"
"이 논문 읽고 정리해줘: [링크]"
"reading_list.md 업데이트해줘"
"이 논문이 우리 연구와 어떻게 다른지 분석해줘"
```

### 코드 작성
```
"[기능] 구현해줘"
"이 코드 리팩토링해줘"
"테스트 코드 작성해줘"
"버그 찾아서 수정해줘"
```

### 실험 관리
```
"실험 설정 만들어줘"
"서버 상태 확인하고 실험 제출해줘"
"실험 결과 분석해줘"
"EXPERIMENT_LOG.md에 결과 기록해줘"
```

### 분석 및 시각화
```
"결과 시각화해줘"
"ablation study 결과 분석해줘"
"baseline과 비교 테이블 만들어줘"
```

---

## Tips

### 효율적인 Claude 활용
1. **컨텍스트 유지**: 프로젝트 시작 시 CLAUDE.md, CONCEPT.md 읽게 하기
2. **구체적 요청**: "코드 작성해줘" → "defocus blur를 시뮬레이션하는 함수 작성해줘"
3. **단계적 진행**: 한 번에 너무 많이 요청하지 않기
4. **피드백 루프**: 결과 확인 후 개선점 요청

### 문서 유지
1. **EXPERIMENT_LOG.md**: 매 실험 후 즉시 기록
2. **CONCEPT.md**: 아이디어 발전 시 업데이트
3. **reading_list.md**: 새 논문 발견 시 추가
