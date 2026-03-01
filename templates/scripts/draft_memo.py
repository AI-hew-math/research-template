#!/usr/bin/env python3
"""
draft_memo.py - Experiment Memo 초안 생성기

Usage:
    python3 ./scripts/draft_memo.py --memo_id <ID> --goal "<GOAL>" --runs <RUN_ID1> [RUN_ID2 ...]

예시:
    python3 ./scripts/draft_memo.py --memo_id memo_lr_sweep --goal "learning rate 영향 분석" --runs 20250301_143022_exp1_host_abc123

출력:
    experiments/memos/<memo_id>.md
    - Observations: 자동으로 run 정보 요약
    - Inferences: 템플릿만 제공 (자동 추론 금지)
"""

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path


def parse_meta_txt(meta_path: Path) -> dict:
    """meta.txt 파싱"""
    meta = {}
    if meta_path.exists():
        for line in meta_path.read_text().strip().split('\n'):
            if ':' in line:
                key, val = line.split(':', 1)
                meta[key.strip()] = val.strip()
    return meta


def get_run_info(run_dir: Path) -> dict:
    """run 디렉토리에서 정보 추출"""
    info = {
        'run_id': run_dir.name,
        'path': str(run_dir),
        'exists': run_dir.exists(),
    }

    if not run_dir.exists():
        return info

    # meta.txt
    meta = parse_meta_txt(run_dir / 'meta.txt')
    info.update(meta)

    # run_card.md에서 exit code 추출
    run_card = run_dir / 'run_card.md'
    if run_card.exists():
        content = run_card.read_text()
        for line in content.split('\n'):
            if '**Exit Code**' in line:
                parts = line.split('|')
                if len(parts) >= 3:
                    info['exit_code'] = parts[2].strip()

    # stdout.log 존재 여부 및 크기
    stdout_log = run_dir / 'stdout.log'
    if stdout_log.exists():
        info['stdout_size'] = stdout_log.stat().st_size

    # stderr.log 존재 여부 및 크기
    stderr_log = run_dir / 'stderr.log'
    if stderr_log.exists():
        info['stderr_size'] = stderr_log.stat().st_size

    return info


def generate_memo(memo_id: str, goal: str, run_ids: list, output_dir: Path, runs_dir: Path) -> Path:
    """Memo 초안 생성"""

    # Run 정보 수집
    run_infos = []
    for run_id in run_ids:
        run_dir = runs_dir / run_id
        info = get_run_info(run_dir)
        run_infos.append(info)

    # Memo 생성
    date_str = datetime.now().strftime('%Y-%m-%d')

    lines = [
        f'# Experiment Memo: {memo_id}',
        '',
        f'> **Goal**: {goal}',
        '>',
        f'> **Date**: {date_str}',
        '',
        '---',
        '',
        '## Observations (FACT)',
        '',
        '> 이 섹션에는 **관측된 사실**만 기록합니다.',
        '> 원인, 이유, 해석은 아래 Inferences 섹션에 작성하세요.',
        '',
        '### Runs Summary',
        '',
        '| Run ID | Exp | Exit | Command |',
        '|--------|-----|------|---------|',
    ]

    # Run 테이블 행 추가
    for info in run_infos:
        run_id = info.get('run_id', 'N/A')
        exp = info.get('EXP_NAME', 'N/A')
        exit_code = info.get('exit_code', info.get('EXIT_CODE', 'N/A'))
        cmd = info.get('COMMAND', 'N/A')
        # 명령어가 너무 길면 자르기
        if len(cmd) > 50:
            cmd = cmd[:47] + '...'
        lines.append(f'| {run_id} | {exp} | {exit_code} | `{cmd}` |')

    lines.extend([
        '',
        '### Run Details',
        '',
    ])

    # 각 run 상세 정보
    for info in run_infos:
        run_id = info.get('run_id', 'N/A')
        lines.append(f'#### {run_id}')
        lines.append('')
        lines.append(f'- **Path**: `{info.get("path", "N/A")}`')
        lines.append(f'- **Command**: `{info.get("COMMAND", "N/A")}`')
        lines.append(f'- **Host**: {info.get("HOSTNAME", "N/A")}')
        lines.append(f'- **Git SHA**: {info.get("GIT_SHA", "N/A")}')
        lines.append(f'- **Exit Code**: {info.get("exit_code", "N/A")}')
        if info.get('stdout_size'):
            lines.append(f'- **stdout.log**: {info["stdout_size"]} bytes')
        if info.get('stderr_size'):
            lines.append(f'- **stderr.log**: {info["stderr_size"]} bytes')
        lines.append('')

    lines.extend([
        '### Raw Facts',
        '',
        '<!-- 각 run에서 관측된 사실을 나열 -->',
        '',
        '- ',
        '',
        '',
        '---',
        '',
        '## Inferences (HYPOTHESIS)',
        '',
        '> 이 섹션에는 **추론/가설**을 기록합니다.',
        '> 각 inference는 반드시 Evidence, Counter-evidence, Confidence를 포함해야 합니다.',
        '',
        '### Inference 1: [제목]',
        '',
        '**Claim**: [주장/가설]',
        '',
        '| Aspect | Description |',
        '|--------|-------------|',
        '| **Evidence** | [이 가설을 지지하는 관측 사실] |',
        '| **Counter-evidence** | [이 가설에 반하는 관측 사실, 없으면 "None observed"] |',
        '| **Confidence** | High / Medium / Low |',
        '',
        '**Reasoning**: [왜 이렇게 생각하는지 간단히]',
        '',
        '---',
        '',
        '### Inference 2: [제목]',
        '',
        '**Claim**: [주장/가설]',
        '',
        '| Aspect | Description |',
        '|--------|-------------|',
        '| **Evidence** | |',
        '| **Counter-evidence** | |',
        '| **Confidence** | High / Medium / Low |',
        '',
        '**Reasoning**:',
        '',
        '---',
        '',
        '## Next Steps',
        '',
        '- [ ] ',
        '',
        '',
        '---',
        '',
        '## Related',
        '',
        '- **Decision Record**: (해당 시 링크)',
        '- **Previous Memo**: ',
    ])

    # 파일 저장
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f'{memo_id}.md'
    output_path.write_text('\n'.join(lines))

    return output_path


def main():
    parser = argparse.ArgumentParser(description='Experiment Memo 초안 생성')
    parser.add_argument('--memo_id', required=True, help='Memo ID (파일명)')
    parser.add_argument('--goal', required=True, help='실험 목표')
    parser.add_argument('--runs', nargs='+', required=True, help='Run ID 목록')

    args = parser.parse_args()

    # 경로 설정
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    runs_dir = project_dir / 'runs'
    output_dir = project_dir / 'experiments' / 'memos'

    # Memo 생성
    output_path = generate_memo(
        memo_id=args.memo_id,
        goal=args.goal,
        run_ids=args.runs,
        output_dir=output_dir,
        runs_dir=runs_dir
    )

    print(f'[draft_memo] Created: {output_path}')
    print(f'[draft_memo] Runs included: {len(args.runs)}')
    print()
    print('Next steps:')
    print('  1. Review Observations section for accuracy')
    print('  2. Fill in Inferences with your analysis')
    print('  3. Add Evidence, Counter-evidence, and Confidence for each inference')


if __name__ == '__main__':
    main()
