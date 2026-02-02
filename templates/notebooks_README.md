# Notebooks

실험 및 분석용 Jupyter 노트북 디렉토리입니다.

## 명명 규칙

```
{번호}_{작성자이니셜}_{설명}.ipynb

예시:
01_hew_data_exploration.ipynb
02_hew_baseline_analysis.ipynb
03_hew_ablation_visualization.ipynb
```

## 노트북 종류

| 접두사 | 용도 | 예시 |
|--------|------|------|
| 0X | 데이터 탐색 | 01_data_exploration |
| 1X | 모델 프로토타이핑 | 10_model_prototype |
| 2X | 실험 분석 | 20_exp_analysis |
| 3X | 시각화 | 30_visualization |
| 9X | 임시/테스트 | 99_scratch |

## Best Practices

### 1. 셀 정리
- 실행 순서대로 정렬
- 불필요한 셀 삭제
- 마크다운으로 섹션 구분

### 2. 재현성
- 상단에 환경/버전 명시
- 랜덤 시드 고정
- 데이터 경로는 상대경로 사용

### 3. 결과 저장
- 중요 figure는 `results/figures/`에 저장
- 분석 결과 테이블은 csv로 저장

### 4. Git 관리
- 출력 제거 후 커밋 (nbstripout 권장)
- 대용량 출력이 있는 노트북은 .gitignore

## 템플릿

```python
# %% [markdown]
# # 노트북 제목
# - 목적:
# - 작성자:
# - 날짜:

# %%
import numpy as np
import matplotlib.pyplot as plt
import torch

# 재현성
SEED = 42
np.random.seed(SEED)
torch.manual_seed(SEED)

# 경로 설정
import sys
sys.path.append('..')
from src.models import MyModel

# %% [markdown]
# ## 1. 데이터 로드

# %%
# 코드...

# %% [markdown]
# ## 2. 분석

# %%
# 코드...

# %% [markdown]
# ## 3. 결론
# - 발견 1
# - 발견 2
```
