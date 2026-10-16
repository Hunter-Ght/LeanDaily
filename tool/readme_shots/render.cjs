// 用 Playwright 把 HTML 渲染成 PNG：node render.cjs <html> <png> <宽> <高>
// 需要先 `npm i playwright-core`（或设置 NODE_PATH 指向已安装的 node_modules）；浏览器用本机 Chrome。
const { chromium } = require('playwright-core');
const [html, png, w, h, transparent] = process.argv.slice(2);
(async () => {
  const exe = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  const browser = await chromium.launch({ executablePath: exe, headless: true });
  const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1.5 });
  await page.goto('file://' + html);
  await page.waitForTimeout(300);
  await page.screenshot({ path: png, omitBackground: transparent === 'transparent' });
  await browser.close();
})();
