#!/bin/bash
# 检查界面代码没有写死颜色、没有使用 Material 外观控件（设计规范：颜色一律来自 theme/tokens.dart）。
exec python3 - "$(cd "$(dirname "$0")/.." && pwd)" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1]) / 'lib'
bad = 0
color = re.compile(r'Color\(0x|Colors\.(?!transparent)')
mat = re.compile(r'\b(Card|ListTile|AppBar|FloatingActionButton|ElevatedButton|TextButton|OutlinedButton|IconButton|InkWell|Scaffold|MaterialApp)\(')
for f in sorted(root.rglob('*.dart')):
    rel = f.relative_to(root).as_posix()
    if rel == 'theme/tokens.dart' or rel.startswith('domain/'):
        continue
    for i, line in enumerate(f.read_text().splitlines(), 1):
        code = line.split('//')[0]
        if color.search(code):
            print(f'{rel}:{i}: hard-coded color: {line.strip()}'); bad = 1
        if mat.search(code):
            print(f'{rel}:{i}: Material widget not allowed: {line.strip()}'); bad = 1
print('lint_tokens ok' if not bad else 'lint_tokens FAILED')
sys.exit(bad)
PY
