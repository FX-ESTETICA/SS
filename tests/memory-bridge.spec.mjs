import { test, expect } from '@playwright/test';

const MEMORY_PATH = '/memory/';
const EXACT_COMMAND = '读取记忆';

async function waitForSnapshot(page) {
  await expect(page.locator('#bridge-status')).toContainText('项目记忆已加载', {
    timeout: 15000,
  });
  await expect(page.locator('#snapshot-summary')).toContainText('Git HEAD');
}

test('精确匹配“读取记忆”时跨窗口成功触发调取', async ({ page, context }) => {
  await page.goto(MEMORY_PATH);

  const popupPromise = context.waitForEvent('page');
  await page.locator('#initial-input').fill(EXACT_COMMAND);
  await page.locator('#open-window-button').click();
  const popup = await popupPromise;

  await popup.waitForLoadState('domcontentloaded');
  await waitForSnapshot(popup);

  await expect(popup.locator('#match-status')).toHaveText('精确匹配');
  await expect(popup.locator('#snapshot-summary')).toContainText('Git HEAD');
});

test('包含附加内容时不会触发调取', async ({ page, context }) => {
  await page.goto(MEMORY_PATH);

  const popupPromise = context.waitForEvent('page');
  await page.locator('#initial-input').fill('读取记忆 立即执行');
  await page.locator('#open-window-button').click();
  const popup = await popupPromise;

  await popup.waitForLoadState('domcontentloaded');
  await expect(popup.locator('#match-status')).toHaveText('未匹配');
  await expect(popup.locator('#bridge-status')).toContainText('未触发项目记忆读取');
  await expect(popup.locator('#snapshot-raw')).toContainText('尚未加载项目记忆。');
});

test('多窗口同时触发时均能正确识别已登录态与记忆读取状态', async ({ page, context }) => {
  await page.goto(MEMORY_PATH);

  const popups = [];
  for (let index = 0; index < 3; index += 1) {
    const popupPromise = context.waitForEvent('page');
    await page.locator('#initial-input').fill(EXACT_COMMAND);
    await page.locator('#open-window-button').click();
    const popup = await popupPromise;
    popups.push(popup);
  }

  for (const popup of popups) {
    await popup.waitForLoadState('domcontentloaded');
    await waitForSnapshot(popup);
    await expect(popup.locator('#match-status')).toHaveText('精确匹配');
  }
});

test('连续 100 次读取平均响应时间不超过 2 秒', async ({ context, baseURL }) => {
  test.setTimeout(240000);
  const durations = [];

  for (let index = 0; index < 100; index += 1) {
    const page = await context.newPage();
    const startedAt = Date.now();
    await page.goto(`${baseURL}${MEMORY_PATH}?initialInput=${encodeURIComponent(EXACT_COMMAND)}`);
    await waitForSnapshot(page);
    durations.push(Date.now() - startedAt);
    await page.close();
  }

  const averageDuration = durations.reduce((sum, value) => sum + value, 0) / durations.length;
  expect(averageDuration).toBeLessThanOrEqual(2000);
});
