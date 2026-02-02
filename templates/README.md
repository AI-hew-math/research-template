# {{PROJECT_NAME}}

> {{DESCRIPTION}}

## Overview

<!-- 프로젝트 개요 -->

## Quick Start

```bash
# 환경 설정
conda create -n {{PROJECT_NAME}} python=3.10
conda activate {{PROJECT_NAME}}
pip install -r requirements.txt

# 학습
python src/training/train.py --config experiments/configs/default.yaml

# 평가
python src/evaluation/evaluate.py --checkpoint results/checkpoints/best.pt
```

## Project Structure

```
{{PROJECT_NAME}}/
├── CONCEPT.md             # 연구 아이디어
├── EXPERIMENT_LOG.md      # 실험 기록
├── survey/                # 논문 서베이
├── experiments/           # 실험 설정
├── src/                   # 소스 코드
├── notebooks/             # Jupyter 노트북
└── results/               # 결과물
```

## Key Results

<!-- 주요 결과 요약 -->

| Method | Metric1 | Metric2 |
|--------|---------|---------|
| Baseline | | |
| Ours | | |

## Citation

```bibtex
@article{your2024paper,
  title={},
  author={},
  journal={},
  year={2024}
}
```

## License

MIT License
