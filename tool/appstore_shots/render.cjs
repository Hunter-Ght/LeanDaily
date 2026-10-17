// 用 Playwright 把 HTML 渲染成指定像素的 PNG（1 倍，不缩放）：node render.cjs <html> <png> <宽> <高>
// 需要 playwright-core（NODE_PATH 指向已安装的 node_modules）和本机 Chrome。
const { chromium } = require('playwright-core');
const [html, png, w, h] = process.argv.slice(2);
(async () => {
  const exe = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const browser = await chromium.launch({ executablePath: exe, headless: true });
  const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
  await page.goto('file://' + html);
  await page.waitForTimeout(400);
  await page.screenshot({ path: png });
  await browser.close();
})();
