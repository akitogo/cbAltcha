# cbAltcha

[ALTCHA](https://altcha.org) proof-of-work spam protection for ColdBox. No third-party service, no
cookies, no tracking: the server signs a challenge, the visitor's browser solves it in the background
(about 1–3 seconds), the server verifies the solution before your handler runs.

- `GET /altcha/challenge`: signed challenge for the widget
- `GET /altcha/widget/altcha.js`: the ALTCHA widget (v3.6.0, MIT), served by the module
- `AltchaGuard` interceptor: every protected request (POST, PUT, PATCH, DELETE by default) needs a valid
  solution in the `altcha` field, otherwise it is answered with 403 and your event never runs

Works on BoxLang (tested with the ColdBox 8 / BoxLang 1.x stack); written in plain CFML script.

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

## License

MIT. The bundled ALTCHA widget (`includes/`) is MIT licensed by its authors, see `includes/LICENSE.txt`.
