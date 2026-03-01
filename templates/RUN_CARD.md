# Run Card: {{RUN_ID}}

> **FACT-ONLY**: 이 문서에는 관측된 사실만 기록합니다.
> 원인 추정, 해석, 가설은 Experiment Memo에 작성하세요.

## Run Info

| Field | Value |
|-------|-------|
| **Run ID** | {{RUN_ID}} |
| **Experiment** | {{EXP_NAME}} |
| **Created** | {{TIMESTAMP}} |
| **Host** | {{HOSTNAME}} |
| **Git SHA** | {{GIT_SHA}} |
| **SLURM Job** | {{SLURM_INFO}} |
| **Exit Code** | {{EXIT_CODE}} |
| **Duration** | {{DURATION}} |

## Command

```bash
{{COMMAND}}
```

## Working Directory

```
{{CWD}}
```

## Key Metrics (fill manually or via script)

| Metric | Value |
|--------|-------|
| Loss | |
| Accuracy | |
| Other | |

## Files in This Run

- `stdout.log` - 표준 출력
- `stderr.log` - 표준 에러
- `meta.txt` - 실행 메타데이터
- `env.txt` - 환경 변수 (있을 경우)
- `git_diff.patch` - uncommitted 변경사항 (있을 경우)
- `nvidia-smi.txt` - GPU 상태 (있을 경우)

## Notes (FACT only)

<!-- 관측된 사실만 기록. 예: "epoch 50에서 loss가 0.001 도달", "OOM 발생" -->


