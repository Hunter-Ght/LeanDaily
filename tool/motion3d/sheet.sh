#!/bin/bash
# 预览联系表：把一个动作按固定间隔截成一排帧，拼成一张图，输出到 out/motion3d/review/<动作>.png。
# 用法：bash tool/motion3d/sheet.sh <动作> [fps=3] [边长=320]；fps 越大帧越密（3 = 每 1/3 秒一帧）。
# 看图时重点检查：姿势是否对（关节没反折、脚踩地、手在该在的位置）、器械有没有穿模、
# 人是否完整在画面内、发力的肌肉是否亮在对的地方。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ex="$1"; fps="${2:-3}"; size="${3:-320}"
dir="$ROOT/out/motion3d/review/$ex"
rm -rf "${dir:?}"; mkdir -p "$dir"
SCENE_QUERY="bg=ebebef" node "$ROOT/tool/motion3d/render.cjs" "$ex" "$dir" "$fps" "$size" | tail -1
n=$(ls "$dir"/*.png | wc -l | tr -d ' ')
cols=8; rows=$(( (n + cols - 1) / cols ))
ffmpeg -loglevel error -y -pattern_type glob -i "$dir/*.png" -vf "tile=${cols}x${rows}" -frames:v 1 "$ROOT/out/motion3d/review/$ex.png"
echo "$ROOT/out/motion3d/review/$ex.png ($n 帧)"
