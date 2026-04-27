import { chromium } from 'playwright-core';

const host = (process.argv[2] || process.env.PLATFORM_BETA_HOST || 'http://localhost:4000').replace(/\/$/, '');
const executablePath = process.env.PLATFORM_CHROMIUM_PATH;

if (!executablePath) {
  console.error('Set PLATFORM_CHROMIUM_PATH to run mobile browser smoke.');
  process.exit(2);
}

const paths = [
  ['app', '/app'],
  ['token staking', '/token-info'],
  ['billing', '/app/billing'],
  ['formation', '/app/formation']
];

const browser = await chromium.launch({ executablePath, headless: true });

try {
  const page = await browser.newPage({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
    deviceScaleFactor: 2
  });

  for (const [name, path] of paths) {
    const response = await page.goto(`${host}${path}`, {
      waitUntil: 'domcontentloaded',
      timeout: 15_000
    });

    if (!response || !response.ok()) {
      throw new Error(`${name} returned HTTP ${response ? response.status() : 'no response'}`);
    }

    const overflow = await page.evaluate(() => {
      const documentWidth = Math.ceil(document.documentElement.scrollWidth);
      const viewportWidth = Math.ceil(window.innerWidth);
      return Math.max(0, documentWidth - viewportWidth);
    });

    if (overflow > 8) {
      throw new Error(`${name} overflows mobile viewport by ${overflow}px`);
    }
  }
} finally {
  await browser.close();
}
