// 带运动模糊的渲染：node render2.cjs <页面> <起始秒> <结束秒> <输出目录> [子帧数=6]
// 以 fps*子帧数 的时间步长逐个截图，之后用 ffmpeg tmix 取半个快门（180°）合成 30 fps。
const { chromium } = require('playwright-core');
const fs = require('fs'), path = require('path');
const [page0, t0, t1, outDir, subArg] = process.argv.slice(2);
const SUB = +(subArg || 6), FPS = 30, root = path.resolve(__dirname, '../..');
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(root, 'out/promo', page0));
  await page.waitForTimeout(600);
  fs.mkdirSync(path.join(root, outDir), { recursive: true });
  const a = Math.round(+t0 * FPS * SUB) , b = Math.round(+t1 * FPS * SUB);
  const start = Date.now();
  for (let i = a; i < b; i++) {
    // 子帧 i 的时间：以所属输出帧为中心，偏移 -SUB/2…（tmix 取其中一半）
    const t = (i - SUB / 2) / (FPS * SUB);
    await page.evaluate(t => window.render(t), Math.max(0, t));
    await page.screenshot({ path: path.join(root, outDir, String(i).padStart(6, '0') + '.jpg'), type: 'jpeg', quality: 92 });
    if (i % 90 === 0) console.log('sub', i, ((Date.now() - start) / 1000).toFixed(0) + 's');
  }
  await browser.close();
})();
