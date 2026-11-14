# Changelog

## 1.0.0 – 2026-11-14

- ALTCHA v2 protocol (as altcha-lib 2.x / widget v3): deterministic challenges with key signature,
  PBKDF2/SHA-256|384|512 and iterated SHA-256|384|512
- `GET /altcha/challenge`, widget delivery (`/altcha/widget/altcha.js`, German translations)
- `AltchaGuard` interceptor: protects POST/PUT/PATCH/DELETE by event include/exclude rules,
  403 JSON or HTML answer, single-use solutions (CacheBox)
- Bundles the ALTCHA widget 3.6.0 (MIT)
