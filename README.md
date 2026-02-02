# Research Project Template

Claude Code와 함께하는 연구 프로젝트 템플릿
**최소한의 구조로 시작, 필요할 때 확장**

---

## 전체 구조

```
Claude_projects/
├── CLAUDE.md              # 전역 지침
├── _knowledge/
│   ├── papers/            # 논문 노트
│   └── lessons_learned.md # 프로젝트 간 교훈
│
├── research-template/     # 이 템플릿
├── ProjectA/
└── ...
```

---

## 처음 시작하기

### 1. 템플릿 설치 (최초 1회)
```bash
git clone https://github.com/AI-hew-math/research-template \
  ~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template

cd ~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template
chmod +x *.sh
```

### 2. 전역 CLAUDE.md 설정 (최초 1회)
```bash
cp templates/GLOBAL_CLAUDE.md ../CLAUDE.md
```

### 3. 지식 베이스 초기화 (최초 1회)
```bash
./init_knowledge.sh
```

---

## 새 프로젝트 만들기

```bash
cd ~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template
./create_project.sh "ProjectName" "연구 주제 설명"
cd ../ProjectName
claude
```

그리고: **"연구 시작하자"**

---

## Claude가 자동으로 하는 것

| 상황 | Claude 행동 |
|------|------------|
| 세션 시작 | EXPERIMENT_LOG.md, CONCEPT.md 확인 |
| 새 논문 발견 | `_knowledge/papers/`에 저장 |
| 실험 교훈 | `_knowledge/lessons_learned.md`에 추가 |
| 실험 시작 전 | `lessons_learned.md` 확인 (과거 실수 방지) |

---

## 지식이 연결되는 방식

```
[ProbeX 프로젝트]
    ↓ topology loss 사용
    ↓
[_knowledge/papers/Chen_2024_TopoLoss.md]
    ↓
    ↓ 같은 논문 참조
    ↓
[SegPH 프로젝트]
```

---

## 확장 기준

**필요할 때만 구조를 추가:**

| 트리거 | 액션 |
|--------|------|
| 한 주제 논문 10개+ | MOC (Map of Content) 생성 |
| 3개+ 프로젝트가 같은 기법 | methods/ 폴더 생성 |

---

## 요약

| 원칙 | 설명 |
|------|------|
| 최소 시작 | papers/ + lessons_learned.md 만으로 시작 |
| 필요시 확장 | 논문 10개+ 될 때 MOC 추가 |
| 간결한 규칙 | Claude 지침은 3개 핵심 규칙만 |
