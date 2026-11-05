#!/bin/bash
# 没有实拍照片的动作：从 3D 场景截两张静帧当封面和示范图，写到 assets/exercises/<动作>/0.jpg（起始）、1.jpg（发力）。
# 规格与实拍照片一致：560×373（3:2）JPEG，人居中、左右补影棚底色，裁成缩略图时也不会切到头脚。
# 用法：bash tool/motion3d/stills.sh <动作> <起始秒> <发力秒>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ex="$1"; start="$2"; peak="$3"
BG=ebebef
out="${STILLS_OUT:-$ROOT/assets/exercises}/$ex"
mkdir -p "$out"
for pair in "0:$start" "1:$peak"; do
  i="${pair%%:*}"; t="${pair#*:}"
  tmp="$ROOT/out/motion3d/stills/$ex-$i"
  rm -rf "$tmp"; mkdir -p "$tmp"
  SCENE_QUERY="bg=$BG" node "$ROOT/tool/motion3d/render.cjs" "$ex" "$tmp" 25 640 "$t" >/dev/null
  ffmpeg -loglevel error -y -i "$tmp/0000.png" \
    -vf "scale=373:373:flags=lanczos,pad=560:373:(ow-iw)/2:0:color=0x$BG" \
    -q:v 3 "$out/$i.jpg"
done
echo "$out: $(ls "$out" | tr '\n' ' ')"
