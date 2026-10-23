#!/usr/bin/env python3
"""仅使用 Python 标准库，从固定版本的 MuscleMap Swift 数据生成资产及映射报告。"""
import argparse
import json
from pathlib import Path
import re
import subprocess

REPO = 'https://github.com/melihcolpan/MuscleMap'
COMMIT = '5f576a5d3d697c3720abfada8e618d1cef08ea32'
ROOT = Path(__file__).resolve().parents[2]
MAPPING = {
    'upperChest': 'chest_up', 'lowerChest': 'chest',
    'frontDeltoid': 'delt_front', 'rearDeltoid': 'delt_rear',
    'biceps': 'biceps', 'triceps': 'triceps', 'upperAbs': 'abs',
    'lowerAbs': 'abs', 'obliques': 'obliques', 'upperBack': 'lats',
    'rhomboids': 'mid_back', 'lowerTrapezius': 'mid_back',
    'lowerBack': 'lower_back', 'quadriceps': 'quads',
    'innerQuad': 'quads', 'outerQuad': 'quads', 'hamstring': 'hamstrings',
    'gluteal': 'glutes', 'calves': 'calves',
}
NEUTRAL = {'head', 'hair', 'neck', 'hands', 'feet', 'knees', 'ankles',
           'forearm', 'adductors', 'tibialis', 'serratus', 'hipFlexors',
           'upperTrapezius', 'rotatorCuff'}
# 父区被完整子区替代，避免重复着色；原始形状仍保存在 groups 中。
REPLACED = {'chest': ('upperChest', 'lowerChest'),
            'abs': ('upperAbs', 'lowerAbs'),
            'trapezius': ('upperTrapezius',),
            'deltoids': ('rearDeltoid',)}


def read_groups(text):
    """严格读取本版本的字面量结构；遇到新增 Swift 表达式立即失败。"""
    groups = {}
    blocks = re.findall(r'BodyPartPathData\(\s*slug:\s*\.(\w+),(.*?)\n        \)',
                        text, re.S)
    if len(blocks) != text.count('BodyPartPathData('):
        raise ValueError('无法识别 BodyPartPathData 结构')
    for name, body in blocks:
        paths = []
        for field in ('common', 'left', 'right'):
            match = re.search(rf'{field}:\s*\[(.*?)\]', body, re.S)
            if match:
                values = '[' + match[1] + ']'
                paths.extend(json.loads(values))
                body = body.replace(match[0], '')
        if body.strip(' \n\t,') or not paths or name in groups:
            raise ValueError(f'无法识别或重复的路径组: {name}')
        groups[name] = paths
    return groups


def convert(source):
    commit = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'],
                                     text=True).strip()
    if commit != COMMIT:
        raise ValueError(f'需要固定上游提交 {COMMIT}，实际为 {commit}')
    data_dir = source / 'Sources/MuscleMap/Data'
    # 防止本地修改使 source.commit 与实际输入不一致。
    subprocess.run(['git', '-C', str(source), 'diff', '--exit-code', 'HEAD', '--',
                    'Sources/MuscleMap/Data', 'LICENSE'], check=True)
    boxes = (data_dir / 'BodyPathData.swift').read_text()
    result = {'source': {'repo': REPO, 'commit': commit, 'license': 'MIT'}}
    report = ['# MuscleMap 肌群映射', '', f'来源：[{REPO}]({REPO})；作者 Melih Colpan；MIT。',
              f'固定提交：`{commit}`。', '',
              '复现：`python3 tool/musclemap/convert.py /tmp/musclemap-src`。仅读取该仓库，不使用其他来源。', '',
              '四视图保留上游坐标及 viewBox。运行时资源只含 `muscles`（按我们的 id 汇总，完全相同的路径去重，不合并子区几何）',
              '和 `other`（未跟踪肌群及非肌肉部位，界面画成中性轮廓）；原始组／子组只记录在本报告里。', '',
              '## 映射判断与限制', '',
              '- 正面 `deltoids` 是整块肩部，单独归 `delt_side`；`frontDeltoid` 归前束。两者有覆盖，未来绘制应先画中束再画前束；没有独立中束几何，不自行裁剪。',
              '- 背面 `deltoids` 由 `rearDeltoid` 替代；胸、腹、斜方肌使用子区替代父区，父区不进资源。',
              '- `upperBack` 是背阔主体，归 `lats`；肩袖 `rotatorCuff` 保留中性。菱形肌与下斜方肌归 `mid_back`；上斜方肌保持中性。',
              '- 股四头父区含中央区域，不能只保留内／外侧子区；保留全部独立形状，同一路径只计一次。',
              '- 两种性别均覆盖全部 16 个 id，无缺失例外。女性背面无 head，头部由 hair 覆盖。',
              '- 完整许可随 assets/legal/ 打包，并在“开源与致谢”页署名。', '']
    for sex in ('male', 'female'):
        result[sex] = {}
        for view in ('front', 'back'):
            key = sex + view.title()
            box = re.search(rf'static let {key} = BodyViewBox\(\s*origin: CGPoint\(x: ([\d.]+), y: ([\d.]+)\),\s*size: CGSize\(width: ([\d.]+), height: ([\d.]+)\)', boxes)
            if box is None:
                raise ValueError(f'缺少 viewBox: {key}')
            groups = read_groups((data_dir / f'{sex.title()}{view.title()}Paths.swift').read_text())
            output = {'viewBox': [float(n) for n in box.groups()],
                      'muscles': {}, 'other': {}}
            report += [f'## {sex} / {view}', '', '| 上游组／子组 | 路径数 | 处理 |', '| --- | ---: | --- |']
            for name, paths in groups.items():
                replacement = REPLACED.get(name)
                if replacement and all(child in groups for child in replacement) and (name != 'deltoids' or view == 'back'):
                    target = '由 ' + '、'.join(replacement) + ' 子区替代（父区不进资源）'
                else:
                    muscle = 'delt_side' if name == 'deltoids' and view == 'front' else MAPPING.get(name)
                    if muscle:
                        bucket = output['muscles'].setdefault(muscle, [])
                        bucket.extend(p for p in paths if p not in bucket)
                        target = f'`{muscle}`'
                    elif name in NEUTRAL:
                        output['other'][name] = paths
                        target = '`other`（中性轮廓）'
                    else:
                        raise ValueError(f'未审核的上游组: {key}/{name}')
                report.append(f'| {name} | {len(paths)} | {target} |')
            result[sex][view] = output
            report.append('')
    asset = ROOT / 'assets/muscle_map.json'
    # 紧凑写出：约 100 KB，App 启动时整份读入。
    asset.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    (ROOT / 'assets/legal/MuscleMap-LICENSE.txt').write_bytes((source / 'LICENSE').read_bytes())
    report += [f'JSON 文件大小：**{asset.stat().st_size:,} 字节**（UTF-8，紧凑格式）。', '']
    (ROOT / 'docs/musclemap-mapping.md').write_text('\n'.join(report))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='仓库外的固定版本 MuscleMap checkout')
    convert(parser.parse_args().source.resolve())
