// 逐帧渲染：node render.cjs <起始秒> <结束秒> [输出目录]；需要 playwright-core（NODE_PATH）和本机 Chrome。
const { chromium } = require('playwright-core');
const fs = require('fs'), path = require('path');
const [t0, t1, outDir = 'out/promo/video'] = process.argv.slice(2);
const root = path.resolve(__dirname, '../..');
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  await page.goto('file://' + path.join(root, 'out/promo/index.html'));
  await page.waitForTimeout(500);
  fs.mkdirSync(path.join(root, outDir), { recursive: true });
  const fps = 30, a = Math.round(+t0 * fps), b = Math.round(+t1 * fps);
  const start = Date.now();
  for (let i = a; i < b; i++) {
    await page.evaluate(t => window.render(t), i / fps);
    await page.screenshot({ path: path.join(root, outDir, String(i).padStart(5, '0') + '.jpg'), type: 'jpeg', quality: 93 });
    if (i % 60 === 0) console.log('frame', i, ((Date.now() - start) / 1000).toFixed(0) + 's');
  }
  await browser.close();
})();
