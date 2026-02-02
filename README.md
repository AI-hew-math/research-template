# Research Project Template

Claude Code와 함께하는 연구 프로젝트 템플릿

---

## 처음 시작하기 (최초 1회)

```bash
# 1. 템플릿 clone
git clone https://github.com/YOUR_USERNAME/research-template \
  ~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template

# 2. 실행 권한 부여
cd ~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template
chmod +x create_project.sh
```

---

## 새 프로젝트 만들기

```bash
# 1. 템플릿 폴더로 이동
cd ~/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template

# 2. 프로젝트 생성
./create_project.sh "프로젝트명" "연구 주제 설명"

# 3. 프로젝트로 이동 + Claude 시작
cd ../프로젝트명
claude
```

### 4. 대화 시작
```
"연구 시작하자"
```

**끝.** Phase를 기억할 필요 없습니다.

---

## Claude가 알아서 하는 것들

| 당신이 하는 말 | Claude가 하는 일 |
|---------------|-----------------|
| "연구 시작하자" | 현재 상태 파악 → 다음 할 일 제안 |
| "관련 논문 조사해줘" | WebSearch → reading_list.md에 추가 |
| "이 논문 정리해줘: [링크]" | 논문 분석 → survey/notes/에 노트 생성 |
| "baseline 구현해줘" | src/에 코드 작성 |
| "실험 돌려줘" | 서버 확인 → sbatch 생성 → 제출 |
| "결과 어때?" | 분석 → EXPERIMENT_LOG.md에 기록 |

---

## 생성되는 프로젝트 구조

```
프로젝트명/
├── CLAUDE.md              # Claude 지시사항 (자동으로 읽힘)
├── CONCEPT.md             # 연구 아이디어 (Claude가 업데이트)
├── EXPERIMENT_LOG.md      # 실험 기록 (Claude가 업데이트)
│
├── survey/                # 논문 서베이
│   ├── reading_list.md    # 논문 목록
│   └── notes/             # 개별 논문 노트
│
├── src/                   # 소스 코드
├── experiments/           # 실험 설정 및 스크립트
├── notebooks/             # Jupyter 노트북
└── results/               # 결과물
```

---

## 예시

```bash
# Defocus Depth 연구 시작
./create_project.sh "DefocusDepth" "Defocus blur를 이용한 depth estimation"
cd ../DefocusDepth
claude
```

```
나: "defocus blur로 depth 추정하는 연구 하고 싶어"

Claude: [관련 논문 조사]
        [CONCEPT.md에 아이디어 정리]
        "기존에 Depth from Defocus 연구가 있네요. 분석해볼까요?"
```

---

## 요약: 전체 흐름

```
┌─────────────────────────────────────────────────────┐
│  처음 1회: git clone → research-template 설치       │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  새 프로젝트: ./create_project.sh "Name" "Desc"     │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  연구 시작: cd ../Name && claude                    │
│             "연구 시작하자"                          │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  이후: 자연스럽게 대화하면 Claude가 알아서 진행     │
└─────────────────────────────────────────────────────┘
```
