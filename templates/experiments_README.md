# Experiments

실험 설정 및 스크립트 관리 디렉토리입니다.

## 구조

```
experiments/
├── README.md          # 이 파일
├── configs/           # Hydra/YAML 설정 파일
│   ├── default.yaml   # 기본 설정
│   ├── model/         # 모델별 설정
│   └── exp/           # 실험별 설정
└── scripts/           # Slurm 스크립트
    └── *.sh           # sbatch 스크립트
```

## Config 관리 (Hydra 스타일)

### 기본 구조
```yaml
# configs/default.yaml
defaults:
  - model: baseline
  - _self_

seed: 42
epochs: 100
batch_size: 32

wandb:
  project: {{PROJECT_NAME}}
  entity: your-entity
```

### 실험별 오버라이드
```yaml
# configs/exp/ablation_lr.yaml
defaults:
  - override /model: proposed

lr: 1e-3
batch_size: 64
```

## Slurm 스크립트 템플릿

### Soda (RTX3090)
```bash
#!/bin/bash
#SBATCH --job-name={{PROJECT_NAME}}_exp1
#SBATCH -o /workspace/dms6721/slurm/o/%x.o%j
#SBATCH -e /workspace/dms6721/slurm/e/%x.e%j
#SBATCH --partition=R3090
#SBATCH --qos=new_default
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

source ~/anaconda3/etc/profile.d/conda.sh
conda activate {{PROJECT_NAME}}
cd ~/projects/{{PROJECT_NAME}}

python src/training/train.py --config experiments/configs/default.yaml
```

### Vegi (RTX4090)
```bash
#!/bin/bash
#SBATCH --job-name={{PROJECT_NAME}}_exp1
#SBATCH -o /workspace/dms6721/slurm/o/%x.o%j
#SBATCH -e /workspace/dms6721/slurm/e/%x.e%j
#SBATCH --partition=R4090
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G

source ~/miniconda3/etc/profile.d/conda.sh
conda activate {{PROJECT_NAME}}
cd ~/projects/{{PROJECT_NAME}}

python src/training/train.py --config experiments/configs/default.yaml
```

## 실험 제출 워크플로우

### 1. 서버 상태 확인
```bash
ssh soda "squeue -u dms6721"
ssh vegi "squeue -u dms6721"
ssh potato "squeue -u dms6721"
```

### 2. 코드 동기화
```bash
sync_to soda  # 또는 vegi, potato
```

### 3. 실험 제출
```bash
ssh soda "cd ~/projects/{{PROJECT_NAME}} && sbatch experiments/scripts/exp1.sh"
```

### 4. 모니터링
```bash
ssh soda "squeue -u dms6721"
ssh soda "tail -f /workspace/dms6721/slurm/o/{{PROJECT_NAME}}_exp1.o*"
```

## 실험 명명 규칙

```
exp{번호}_{설명}.sh

예시:
- exp01_baseline.sh
- exp02_ablation_lr.sh
- exp03_proposed_v1.sh
```

## Slack 알림

실험 제출 시 반드시 3단계 알림 설정:
1. 시작 알림
2. 개별 완료 알림
3. 전체 완료 요약

자세한 내용은 전역 CLAUDE.md 참조
