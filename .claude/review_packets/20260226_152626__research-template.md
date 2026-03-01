# Review Packet — research-template
- Timestamp: 2026-02-26T06:26:26Z
- Run ID: 20260226_152626_48573
- Repo Root: /Users/mac_hew/Library/CloudStorage/OneDrive-postech.ac.kr/Claude_projects/research-template
- Branch: main
- HEAD: 1dbe512

## 1) Objective (1–2 lines)
- 참고로 서버는 ssh soda, vegi, potato 3개야. soda만 돌리지 말고 리소스 제약이 생길경우 (pending 을 해야하는 ) 상황에 맞게 다른 서버에 올리도록 해줘.  이때 올리는 실험에 대한 프로젝트와 실험명을 명시해야해 (나중에 헷갈려 뭐가 뭔지). 그리고 어느 서버에 올렸는지 실험로그도 기록해야하고. 

## 2) What changed (max 10 lines)
### git status (porcelain, max 10 lines)
```
 M CLAUDE.md
 M README.md
 M create_project.sh
 M init_knowledge.sh
 M scripts/ph_analysis.png
 M scripts/ph_feasibility_check.py
 M scripts/requirements_ph.txt
 M scripts/run_ph_check.sh
 M templates/CONCEPT.md
 M templates/GLOBAL_CLAUDE.md
```
### git diff --stat (max 10 lines)
```
 scripts/requirements_ph.txt            |   0
 scripts/run_ph_check.sh                |   0
 templates/CONCEPT.md                   |   0
 templates/GLOBAL_CLAUDE.md             |   0
 templates/README.md                    |   0
 templates/REVIEW_PACKET.md             |   0
 templates/knowledge/INDEX.md           |   0
 templates/knowledge/lessons_learned.md |   0
 templates/paper_note_TEMPLATE.md       |   0
 15 files changed, 0 insertions(+), 0 deletions(-)
```

### .claude/ directory changes
*(These files are gitignored and tracked separately from `git status` above)*

[...remaining .claude/ files omitted — cap reached]

### Diff snippets
### CLAUDE.md
```diff
diff --git a/CLAUDE.md b/CLAUDE.md
old mode 100644
new mode 100755
```
### create_project.sh
```diff
diff --git a/create_project.sh b/create_project.sh
old mode 100644
new mode 100755
```
### init_knowledge.sh
```diff
diff --git a/init_knowledge.sh b/init_knowledge.sh
old mode 100644
new mode 100755
```
### README.md
```diff
diff --git a/README.md b/README.md
old mode 100644
new mode 100755
```
### scripts/ph_analysis.png
```diff
diff --git a/scripts/ph_analysis.png b/scripts/ph_analysis.png
old mode 100644
new mode 100755
```
### scripts/ph_feasibility_check.py
```diff
diff --git a/scripts/ph_feasibility_check.py b/scripts/ph_feasibility_check.py
old mode 100644
new mode 100755
```
### scripts/requirements_ph.txt
```diff
diff --git a/scripts/requirements_ph.txt b/scripts/requirements_ph.txt
old mode 100644
new mode 100755
```
### scripts/run_ph_check.sh
```diff
diff --git a/scripts/run_ph_check.sh b/scripts/run_ph_check.sh
old mode 100644
new mode 100755
```
### templates/CONCEPT.md
```diff
diff --git a/templates/CONCEPT.md b/templates/CONCEPT.md
old mode 100644
new mode 100755
```

[...remaining diffs omitted — 1200 char cap]

## 3) Key evidence (max 60 lines total)
### 3.1 Recent commits (5)
```
1dbe512 Revert "Add experiment naming rules: enforce project name prefix in all experiments"
0f3aa9f Add experiment naming rules: enforce project name prefix in all experiments
f8a3c65 experiment-tracker v2: 3-tier auto-detection, boundary matching, split files
7ac9157 Fix cross-platform compatibility in experiment-tracker
19193b5 Add experiment-tracker: terminal tab title experiment status display
```
### 3.2 Commands executed (max 10 lines)
```
N/A
```
### 3.3 Logs / Errors (max 40 lines)
```

```

## 4) Review scores (from prior hooks in this session)
- PostToolUse Code: N/A
- Stop Conv: N/A/10 (informational only)
- Notes: These are from earlier hook runs in this session, NOT the current review

## 5) Current state assessment (max 12 lines)
- Done:
  - Last commit: 1dbe512 Revert "Add experiment naming rules: enforce project name prefix in all experiments"
- Risks / Unknowns:
  - Many uncommitted changes (19 files)

## 6) Next Steps (evidence-based) (max 15 lines)
- [P0] Commit pending changes — Evidence: git status shows 19 modified files — Command: git add -A && git commit -m "..."

## 7) Next Claude Prompt (copy/paste) (max 40 lines)
```text
Commit the pending changes with a descriptive message.

A) Task:
- Complete the highest priority item from Next Steps
- Address any errors or issues identified

B) Constraints:
- One change at a time
- Evidence required for claims
- Keep outputs concise

C) Exit criteria:
- All P0 items resolved
- Code compiles/runs without errors
- Changes committed if appropriate
```
