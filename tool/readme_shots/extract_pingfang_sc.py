#!/usr/bin/env python3
"""从 macOS 的 PingFang.ttc 里抽出“苹方-简”常规体，供截图使用（输出到 out/fonts/，不提交）。

测试里的 FontLoader 只会读字体集合的第 0 套字形（港版，缺少“稳”“都”等简体字），
所以先抽出简体那一套，再用 LEANDAILY_TEST_FONT 指向它。需要 `pip install fonttools`。
"""
import glob
import sys
from pathlib import Path

from fontTools.ttLib import TTCollection

paths = glob.glob('/System/Library/AssetsV2/com_apple_MobileAsset_Font*/*/AssetData/PingFang.ttc')
if not paths:
    sys.exit('找不到 PingFang.ttc（仅 macOS 有）')
ttc = TTCollection(paths[0])
face = next(f for f in ttc.fonts if (f['name'].getDebugName(4) or '') == 'PingFang SC Regular')
out = Path(__file__).resolve().parents[2] / 'out/fonts/PingFangSC-Regular.ttf'
out.parent.mkdir(parents=True, exist_ok=True)
face.save(out)
print('wrote', out)
