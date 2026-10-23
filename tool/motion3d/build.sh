#!/bin/bash
# 把一个或多个动作渲染成 App 用的动画 WebP，并更新 assets/motion3d/manifest.json。
# 用法：bash tool/motion3d/build.sh squat [pushup ...]
# 规格：512 渲染 → 256×256、24 fps、不透明影棚底（与 App 里的 studio 色一致）、有损 q70。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$ROOT/out/tools/libwebp-1.6.0-mac-arm64/bin"
BG=ebebef SIZE=256 FPS=24 Q=70
mkdir -p "$ROOT/assets/motion3d"
for ex in "$@"; do
  tmp="$ROOT/out/motion3d/build/$ex"
  rm -rf "$tmp"; mkdir -p "$tmp/small"
  SCENE_QUERY="bg=$BG" node "$ROOT/tool/motion3d/render.cjs" "$ex" "$tmp" "$FPS" 512 >/dev/null
  ffmpeg -loglevel error -y -i "$tmp/%04d.png" -vf "scale=$SIZE:$SIZE:flags=lanczos" "$tmp/small/%04d.png"
  "$BIN/img2webp" -loop 0 -lossy -q "$Q" -m 6 -d $((1000 / FPS)) "$tmp"/small/*.png -o "$ROOT/assets/motion3d/$ex.webp" >/dev/null
  frames=$(ls "$tmp"/small/*.png | wc -l | tr -d ' ')
  python3 - "$ROOT" "$ex" "$frames" "$FPS" "$SIZE" "$BG" "$tmp/meta.json" <<'PY'
import json, sys, pathlib
root, ex, frames, fps, size, bg, meta = sys.argv[1:]
m = json.loads(pathlib.Path(meta).read_text())
path = pathlib.Path(root) / 'assets/motion3d/manifest.json'
data = json.loads(path.read_text()) if path.exists() else {'version': 1, 'exercises': {}}
data.update({'size': int(size), 'fps': int(fps), 'background': '#' + bg})
data['exercises'][ex] = {
    'file': f'assets/motion3d/{ex}.webp',
    'frames': int(frames),
    'period': m['period'],
    'peakFrame': min(int(frames) - 1, round(m['peak'] * int(fps))),
    'phases': [[round(t * int(fps)), name] for t, name in m['phases']],
}
data['exercises'] = dict(sorted(data['exercises'].items()))
path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
PY
  echo "$ex: $frames frames, $(du -k "$ROOT/assets/motion3d/$ex.webp" | cut -f1) KB"
done
