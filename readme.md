# cbAltcha

[![Tests](https://github.com/akitogo/cbAltcha/actions/workflows/tests.yml/badge.svg)](https://github.com/akitogo/cbAltcha/actions/workflows/tests.yml)

[ALTCHA](https://altcha.org) proof-of-work spam protection for ColdBox: a privacy-friendly,
GDPR-friendly alternative to Google reCAPTCHA, hCaptcha or Cloudflare Turnstile. The server signs a
challenge, the visitor's browser solves it in the background (about 1–3 seconds), the server verifies
the solution before your handler runs. No third-party service is involved (see [Privacy](#privacy)).

- `GET /altcha/challenge`: signed challenge for the widget
- `GET /altcha/widget/altcha.js`: the ALTCHA widget (v3, MIT, exact version in `box.json` → `altchaWidget`), served by the module
- `AltchaGuard` interceptor: every protected request (POST, PUT, PATCH, DELETE by default) needs a valid
  solution in the `altcha` field, otherwise it is answered with 403 and your event never runs

Works on BoxLang (tested with the ColdBox 8 / BoxLang 1.x stack); written in plain CFML script.

## Privacy

What happens with visitors' data, for your privacy policy and data protection assessment:

- **No third-party requests.** The widget script, its translations and the challenges come from your own
  server (`/altcha/...`). Nothing is loaded from or sent to altcha.org, Google or any other service; the
  "Protected by ALTCHA" line in the widget is a plain link.
- **No cookies, no local storage.** The widget does not set cookies (unless you configure its `setCookie`
  option); the module sets none.
- **No tracking, no fingerprinting, no profiling.** Spam protection works through computation (proof of
  work), not by observing the visitor.
- **No personal data stored.** Challenges are stateless (signed). For replay protection the module keeps
  only the challenge signature in CacheBox until the challenge expires: no IP address, no form data.

That is why, unlike reCAPTCHA, it needs no consent banner entry and no data processing agreement with a
third party. Whether a whole site is GDPR compliant depends on more than its captcha: this describes
what cbAltcha does, it is not legal advice.

## Install

```bash
box install cbAltcha
```

Set a secret (at least 32 random bytes), e.g. in `.env`:

```bash
ALTCHA_HMAC_SECRET=$(openssl rand -hex 32)
```

Without it the module uses a random secret until the application restarts (open challenges then fail).

## Add the widget to your forms

```html
<form method="post" action="/contact">
  …
  <altcha-widget name="altcha" challenge="/altcha/challenge" auto="onfocus"></altcha-widget>
  <button type="submit">Send</button>
</form>
<script type="module" src="/altcha/widget/altcha.js"></script>
```

- `auto="onfocus"` starts solving when a field of the form gets focus, so it is usually done before
  the visitor has finished typing. `auto="onsubmit"` solves on submit instead.
- German texts: load `/altcha/widget/i18n/de.js` after the widget and set `language="de"`.
- The widget needs a secure context (HTTPS or localhost).

### Forms sent with `fetch`

The widget renders a **required** checkbox into the form. Until it is solved the browser blocks the
submit (no `submit` event fires) and the widget starts solving: the visitor has to click again. With
`auto="onsubmit"` the widget resubmits by itself. With other modes, or when you send the form with
`fetch`, wait for the solution yourself:

```js
const widget = form.querySelector('altcha-widget');
submitButton.addEventListener('click', async (e) => {
  if (widget.getState() === 'verified') return;      // normal submit
  e.preventDefault();
  const result = await widget.verify();               // { payload } or null
  if (result) form.requestSubmit(submitButton);
}, true);
```

With `fetch`, `new FormData(form)` contains the `altcha` field. A solution is accepted **once**: call
`widget.reset()` after every attempt, including failed ones (validation errors, network errors).

Rejected requests get `403` with `{ "ok": false, "errors": [ "altcha" ], "reason": "…" }` when the
request asks for JSON (`Accept: application/json` or `X-Requested-With`), otherwise a short HTML page.
Reasons: `missing`, `malformed`, `expired`, `signature`, `solution`, `replayed`.

## Settings

Override in `config/modules/cbAltcha.cfc` (ColdBox 7+) or `moduleSettings.cbAltcha` in `config/ColdBox.cfc`:

| Setting | Default | |
|---|---|---|
| `hmacSecret` | `ALTCHA_HMAC_SECRET` | Signing secret. The key-signature secret is derived from it. |
| `algorithm` | `PBKDF2/SHA-256` | Also `PBKDF2/SHA-384`, `PBKDF2/SHA-512`, `SHA-256`, `SHA-384`, `SHA-512` |
| `cost` | `2000` | Iterations per attempt |
| `counterMin`, `counterMax` | `2000`, `5000` | Attempts the browser needs (random in this range) |
| `expires` | `1200` | Seconds a challenge stays valid |
| `fieldName` | `altcha` | Form field with the payload |
| `cacheName` | `default` | CacheBox cache for used solutions |
| `methods` | `POST, PUT, PATCH, DELETE` | HTTP methods that are checked |
| `includeEvents` | `[]` | Regexes on the event (`module:handler.action`); empty = all events |
| `excludeEvents` | `[ "^cbAltcha:" ]` | Regexes on the event that are never checked |
| `rejectEvent` | `cbAltcha:main.rejected` | Event answering a rejected request; `prc.altcha.reason` is set |
| `enabled` | `true` | `false` switches the interceptor off (the service still works) |

Difficulty: the browser needs `counter` key derivations of `cost` iterations. With the defaults that is
about 1–3 s on a laptop using several workers; double either value and the time doubles. Phones are slower.

**Exclude what has its own authentication.** Every matching POST without a solution is rejected, so
exclude admin areas, APIs, logins with their own protection, webhooks etc. Example for ContentBox:

```js
// config/modules/cbAltcha.cfc
component {
	function configure(){
		return {
			hmacSecret    : getSystemSetting( "ALTCHA_HMAC_SECRET", "" ),
			excludeEvents : [
				"^cbAltcha:",
				"^contentbox-admin:", "^contentbox-security:", "^contentbox-filebrowser:",
				"^contentbox-ckeditor:", "^contentbox-markdowneditor:", "^contentbox-api",
				"^contentbox-ui:(content\.previewSite|page\.preview|blog\.preview)$"
			]
		};
	}
}
```

Overriding `excludeEvents` replaces the default list: keep `^cbAltcha:`.

## Using the service directly

```js
property name="altcha" inject="AltchaService@cbAltcha";

var challenge = altcha.createChallenge();          // struct for JSON
var result    = altcha.verify( rc.altcha );        // { verified, reason }
```

## How it works

The ALTCHA v2 protocol as implemented by altcha-lib 2.x, in deterministic mode with key signatures:

1. The server picks a secret random `counter`, random `nonce` and `salt` (16 bytes each) and derives
   `key = KDF( nonce + uint32BE(counter), salt, cost )`. The challenge carries the first half of the key
   (`keyPrefix`), `keySignature = HMAC( keySecret, key )`, `expiresAt`, and
   `signature = HMAC( secret, canonical JSON of all parameters )`.
2. The widget tries counters until a derived key starts with `keyPrefix` and submits
   `base64( { challenge: { parameters, signature }, solution: { counter, derivedKey } } )`.
3. The server checks expiry, the parameter signature and `HMAC( keySecret, derivedKey ) == keySignature`
   (constant-time comparisons), then remembers the challenge until it expires (single use).

Verification costs two HMACs; the key derivation happens once per challenge on creation (~20–40 ms).
Java's `PBKDF2WithHmac*` cannot take binary passwords, so PBKDF2 is implemented on `javax.crypto.Mac`.

## Tests

The specs live in `test-harness/`, a minimal ColdBox app that loads the module from the package root
(the package folder must be named `cbAltcha`). It runs on BoxLang with `bx-compat-cfml`.

```bash
box run-script test:setup   # installs ColdBox + TestBox into test-harness/, starts the server on :60455
box run-script test         # testbox run
box run-script test:stop
```

- `tests/specs/unit/AltchaServiceSpec.cfc`: key derivation against reference values from Node's crypto
  and RFC 7914, canonical JSON and HMAC signing as altcha-lib does it, challenge creation, and every
  verification outcome (valid, replayed, missing, malformed, expired, tampered, wrong secret, wrong solution)
- `tests/specs/integration/AltchaGuardSpec.cfc`: real requests through the interceptor and routes:
  protected and excluded events, HTTP methods, include rules, `enabled`, JSON and HTML rejections,
  widget delivery

The harness solves challenges in the specs with low difficulty settings (`cost` 10, counter 5–15).

Browser specs (`test-harness/e2e/`, Playwright with Chromium) load a test form (`/form`) with the real
widget and check that it solves cbAltcha's challenges, posts the payload format cbAltcha verifies (in
`auto="onfocus"` and `auto="onsubmit"` mode), loads the German texts, and that a post without a solution
is rejected. With the test server running:

```bash
cd test-harness/e2e
npm ci && npx playwright install chromium
npx playwright test
```

GitHub Actions runs both suites on every push and pull request.

## Widget updates

The bundled widget version is recorded in `box.json` (`altchaWidget`). The *Update ALTCHA widget*
workflow checks npm every Monday:

- **Same major version** (e.g. 3.6 → 3.7): it swaps in the new widget, runs the server and browser specs
  with it, and opens a pull request if they pass. Merge it, bump the version, tag a release.
- **New major version** (e.g. 4.0): it opens an issue instead. Majors can change widget attributes, the
  JavaScript API or the challenge protocol, so they need a human look.

Run it manually (*Actions → Update ALTCHA widget → Run workflow*) to try a specific version; with
*dry run* it only tests. Locally: `.github/scripts/update-widget.sh 3.7.0`.

## License

MIT. The bundled ALTCHA widget (`includes/`) is MIT licensed by its authors, see `includes/LICENSE.txt`.
