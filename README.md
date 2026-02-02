# Research Project Template

Claude Code와 함께하는 연구 프로젝트 템플릿
**지식이 축적되고 프로젝트 간 연결되는 구조**

---

## 전체 구조

```
Claude_projects/
├── CLAUDE.md              # 전역 지침 (Claude가 항상 참조)
├── _knowledge/            # 공유 지식 베이스
│   ├── concepts/          # 원자적 개념 노트
│   ├── papers/            # 논문 노트
│   ├── methods/           # 재사용 기법
│   ├── MOCs/              # 주제별 가이드
│   └── lessons_learned.md # 축적된 교훈
│
├── research-template/     # 이 템플릿
├── ProjectA/              # 개별 프로젝트들
├── ProjectB/
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
| 새 주제 작업 시작 | `_knowledge/MOCs/`에서 관련 MOC 먼저 확인 |
| 새 논문 발견 | `_knowledge/papers/`에 저장 + MOC 업데이트 |
| 새 개념 정리 | `_knowledge/concepts/`에 저장 |
| 재사용 가능한 기법 발견 | `_knowledge/methods/`에 저장 |
| 실험 실패/성공 교훈 | `_knowledge/lessons_learned.md`에 추가 |
| 새 실험 시작 전 | `lessons_learned.md` 확인 (과거 실수 방지) |

---

## 지식이 연결되는 방식

```
[ProbeX 프로젝트]
    ↓ topology loss 사용
    ↓
[_knowledge/MOCs/MOC_topology.md] ← 주제 가이드
    ↓ 링크
    ↓
[_knowledge/concepts/persistent_homology.md] ← 개념
[_knowledge/papers/Chen_2024_TopoLoss.md] ← 논문
    ↓
    ↓ 같은 개념 사용
    ↓
[SegPH 프로젝트]
```

**결과**:
- 논문은 한 번만 정리
- 개념은 프로젝트 간 공유
- 한 프로젝트의 교훈이 다른 프로젝트에 전달

---

## 파일 구조 요약

### 프로젝트별 (개별)
```
ProjectName/
├── CLAUDE.md          # 프로젝트 지침
├── CONCEPT.md         # 이 프로젝트 아이디어
├── EXPERIMENT_LOG.md  # 이 프로젝트 실험 기록
└── src/, experiments/, ...
```

### 공유 (_knowledge/)
```
_knowledge/
├── concepts/          # 모든 프로젝트가 참조
├── papers/            # 모든 프로젝트가 참조
├── methods/           # 재사용 코드/기법
├── MOCs/              # 주제별 "목차"
└── lessons_learned.md # 전체 교훈
```

---

## 예시 워크플로우

```
나: "topology 기반 segmentation 연구 시작하자"

Claude:
  1. _knowledge/MOCs/MOC_topology.md 확인
  2. 관련 논문, 개념 파악
  3. "기존에 TopoLoss 관련 논문 3개 있어요.
      ProbeX에서 erosion=3이 최적이었네요."
  4. CONCEPT.md에 아이디어 정리
  5. "새 MOC 만들까요? MOC_topo_segmentation.md"
```

---

## 요약

| 기존 문제 | 해결 |
|----------|------|
| 프로젝트가 고립됨 | `_knowledge/`로 연결 |
| 같은 논문 여러 번 정리 | 한 곳에 저장, 여러 곳에서 참조 |
| 과거 실수 반복 | `lessons_learned.md`로 방지 |
| Claude가 구조 모름 | CLAUDE.md에 명확한 지침 |
