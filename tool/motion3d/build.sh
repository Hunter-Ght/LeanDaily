#!/bin/bash
# 把一个或多个动作渲染成 App 用的动画 WebP，并更新 assets/motion3d/manifest.json。
# 用法：bash tool/motion3d/build.sh squat [pushup ...]
# 规格：640 渲染 → 448×448（动作要点卡片在 3 倍屏上约 690 像素高，再小会糊）、25 fps（每帧正好 40 毫秒，WebP 时长只能存整数毫秒）、不透明影棚底（与 App 里的 studio 色一致）、有损 q65。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="$ROOT/out/tools/libwebp-1.6.0-mac-arm64/bin"
BG=ebebef SIZE=448 FPS=25 Q=65
mkdir -p "$ROOT/assets/motion3d"
for ex in "$@"; do
  tmp="$ROOT/out/motion3d/build/$ex"
  rm -rf "$tmp"; mkdir -p "$tmp/small"
  SCENE_QUERY="bg=$BG" node "$ROOT/tool/motion3d/render.cjs" "$ex" "$tmp" "$FPS" 640 >/dev/null
  ffmpeg -loglevel error -y -i "$tmp/%04d.png" -vf "scale=$SIZE:$SIZE:flags=lanczos" "$tmp/small/%04d.png"
  "$BIN/img2webp" -loop 0 -lossy -q "$Q" -m 6 -d $((1000 / FPS)) "$tmp"/small/*.png -o "$ROOT/assets/motion3d/$ex.webp" >/dev/null
  # img2webp 会把连续相同的帧（停顿）合并成一帧并加长时长，所以帧数以文件为准、节奏一律按毫秒记。
  frames=$("$BIN/webpinfo" -summary "$ROOT/assets/motion3d/$ex.webp" | sed -n 's/.*Number of frames: *//p')
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
    'periodMs': round(m['period'] * 1000),
    'peakMs': round(m['peak'] * 1000),
    'phases': [[round(t * 1000), name] for t, name in m['phases']],
}
data['exercises'] = dict(sorted(data['exercises'].items()))
path.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n')
PY
  echo "$ex: $frames frames, $(du -k "$ROOT/assets/motion3d/$ex.webp" | cut -f1) KB"
done
