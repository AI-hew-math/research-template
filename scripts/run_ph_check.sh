#!/bin/bash
#SBATCH --job-name=ph_check
#SBATCH -o /workspace/dms6721/slurm/o/%x.o%j
#SBATCH -e /workspace/dms6721/slurm/e/%x.e%j
#SBATCH --partition=R3090
#SBATCH --qos=gpu_qos_2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:0
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# Feasibility Check: PH for 3D Scene Graph
# GPU 필요 없음 - CPU만 사용

source ~/anaconda3/etc/profile.d/conda.sh

# 환경 생성 (처음 한 번만)
if ! conda env list | grep -q "ph_check"; then
    echo "Creating conda environment..."
    conda create -n ph_check python=3.10 -y
fi

conda activate ph_check

# 패키지 설치
pip install numpy gudhi scikit-learn matplotlib tqdm h5py --quiet

# 실행
cd ~/projects/research-template
python scripts/ph_feasibility_check.py \
    --n_samples 200 \
    --save_path scripts/ph_analysis.png

echo "Done! Check scripts/ph_analysis.png"
