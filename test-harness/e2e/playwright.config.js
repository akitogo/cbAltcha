// Browser specs for cbAltcha: run against the test harness server (box server start in the package root)
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
  testDir: '.',
  timeout: 60_000,
  workers: 1,
  reporter: 'list',
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:60455',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
