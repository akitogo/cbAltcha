# Changelog

## Unreleased

- Browser specs (Playwright): the real widget against the test harness, both `auto` modes, payload format
- Weekly *Update ALTCHA widget* workflow: pull request for new widget versions in the same major
  (after server and browser specs pass), issue for new major versions
- Bundled widget version recorded in `box.json` (`altchaWidget`)
- Test harness: `index.cfm` no longer processes the request a second time

## 1.0.1 – 2026-11-14

- TestBox specs with a ColdBox test harness (`test-harness/`), 38 specs, run by GitHub Actions on every push
- Module routes answer a wrong HTTP method with 405 instead of an exception
- Rejection handler reads request headers with one argument (same behaviour, testable with mocked headers)

## 1.0.0 – 2026-11-14

- ALTCHA v2 protocol (as altcha-lib 2.x / widget v3): deterministic challenges with key signature,
  PBKDF2/SHA-256|384|512 and iterated SHA-256|384|512
- `GET /altcha/challenge`, widget delivery (`/altcha/widget/altcha.js`, German translations)
- `AltchaGuard` interceptor: protects POST/PUT/PATCH/DELETE by event include/exclude rules,
  403 JSON or HTML answer, single-use solutions (CacheBox)
- Bundles the ALTCHA widget 3.6.0 (MIT)
