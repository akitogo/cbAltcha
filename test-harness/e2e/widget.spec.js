// The real ALTCHA widget (includes/altcha.min.js) against cbAltcha's challenge endpoint and interceptor.
// These specs are what makes widget updates safe: they fail if a new widget can't solve our challenges,
// submits a different payload, or changes the attributes/API we rely on.
const { test, expect } = require('@playwright/test');

const widgetState = (page) => page.evaluate(() => document.querySelector('altcha-widget')?.getState?.());

test('auto="onfocus": solves while the visitor types, the form posts natively', async ({ page }) => {
  await page.goto('/form');
  await page.fill('#name', 'Alice');                      // focus starts solving
  await expect.poll(() => widgetState(page), { timeout: 30_000 }).toBe('verified');
  const [response] = await Promise.all([page.waitForNavigation(), page.click('#send')]);
  expect(response.status()).toBe(200);
  await expect(page.locator('body')).toHaveText('submitted: Alice');
});

test('auto="onsubmit": the widget solves on submit and resubmits by itself', async ({ page }) => {
  await page.goto('/form?auto=onsubmit');
  await page.fill('#name', 'Bob');
  expect(await widgetState(page)).toBe('unverified');
  const [response] = await Promise.all([page.waitForNavigation({ timeout: 30_000 }), page.click('#send')]);
  expect(response.status()).toBe(200);
  await expect(page.locator('body')).toHaveText('submitted: Bob');
});

test('submits the payload format cbAltcha verifies (protocol v2)', async ({ page }) => {
  await page.goto('/form');
  await page.fill('#name', 'Carol');
  await expect.poll(() => widgetState(page), { timeout: 30_000 }).toBe('verified');
  const [request] = await Promise.all([page.waitForRequest((r) => r.method() === 'POST'), page.click('#send')]);
  const field = new URLSearchParams(request.postData()).get('altcha');
  const payload = JSON.parse(Buffer.from(field, 'base64').toString('utf8'));
  expect(Object.keys(payload.challenge.parameters).sort()).toEqual(
    ['algorithm', 'cost', 'expiresAt', 'keyLength', 'keyPrefix', 'keySignature', 'nonce', 'salt']);
  expect(payload.challenge.signature).toMatch(/^[0-9a-f]{64}$/);
  expect(Number.isInteger(payload.solution.counter)).toBe(true);
  expect(payload.solution.derivedKey).toMatch(/^[0-9a-f]{64}$/);
  expect(payload.solution.derivedKey.startsWith(payload.challenge.parameters.keyPrefix)).toBe(true);
});

test('German texts load with language="de"', async ({ page }) => {
  await page.goto('/form?lang=de');
  await expect(page.locator('altcha-widget')).toContainText('Ich bin kein Roboter');
});

test('a post without a solution is rejected', async ({ request }) => {
  const response = await request.post('/submit', { form: { name: 'Mallory' } });
  expect(response.status()).toBe(403);
});
