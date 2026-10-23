#!/usr/bin/env python3
"""把 tool/motion3d/entries/*.json 合并成 assets/motion3d/manifest.json。
build.sh 只写各动作自己的 entries/<动作>.json（并行开发时互不冲突）；清单由这个脚本统一生成。"""
import json, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
entries = {p.stem: json.loads(p.read_text()) for p in sorted((root / 'tool/motion3d/entries').glob('*.json'))}
out = {'version': 1, 'size': 448, 'fps': 25, 'background': '#ebebef', 'exercises': entries}
(root / 'assets/motion3d/manifest.json').write_text(json.dumps(out, ensure_ascii=False, indent=1) + '\n')
print(len(entries), 'exercises')
