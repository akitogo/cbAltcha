/**
 * cbAltcha: ALTCHA proof-of-work spam protection for ColdBox
 * ---
 * https://altcha.org, no third-party service involved:
 * - GET  /altcha/challenge          signed challenge for the <altcha-widget>
 * - GET  /altcha/widget/altcha.js   the ALTCHA widget (v3, MIT), served by this module
 * - Interceptor AltchaGuard         checks the "altcha" field on every protected request (POST etc.)
 *
 * Implements the ALTCHA v2 protocol in "deterministic" mode with key signatures, as
 * altcha-lib 2.x does: the server derives the key once when it creates the challenge,
 * verification is two HMAC comparisons. Each solution is accepted once (replay protection
 * in CacheBox until the challenge expires).
 *
 * Override any setting in config/modules/cbAltcha.cfc (ColdBox 7+) or moduleSettings.cbAltcha.
 * See readme.md.
 */
component {

	this.title          = "cbAltcha";
	this.description    = "ALTCHA proof-of-work protection for form posts";
	this.version        = "1.0.1";
	this.author         = "Gunnar Lieb";
	this.entryPoint     = "altcha";
	this.modelNamespace = "cbAltcha";
	this.cfmapping      = "cbAltcha";
	this.autoMapModels  = true;

	function configure(){
		settings = {
			// HMAC secret for challenge signatures. Set ALTCHA_HMAC_SECRET in production:
			// without it a random secret is generated on every app start (challenges then die with a restart).
			hmacSecret     : getSystemSetting( "ALTCHA_HMAC_SECRET", "" ),
			// Proof of work: PBKDF2/SHA-256 | SHA-256 (iterated). cost = iterations per attempt,
			// counter = attempts the browser needs (random between min and max).
			algorithm      : "PBKDF2/SHA-256",
			cost           : 2000,
			counterMin     : 2000,
			counterMax     : 5000,
			// Seconds a challenge stays valid (the widget fetches a new one when it expires)
			expires        : 1200,
			// Form field the widget submits
			fieldName      : "altcha",
			// Cache for replay protection
			cacheName      : "default",
			// --- Interceptor: which requests must carry a valid solution ---
			// HTTP methods that are checked
			methods        : [ "POST", "PUT", "PATCH", "DELETE" ],
			// Regexes on the event name (module:handler.action). Empty = every event not excluded.
			includeEvents  : [],
			// Regexes on the event name that are never checked
			excludeEvents  : [ "^cbAltcha:" ],
			// Event that answers a rejected request (403). Gets prc.altcha = { reason }.
			rejectEvent    : "cbAltcha:main.rejected",
			// Switch the interceptor off (e.g. in tests): the service still works
			enabled        : true
		};

		interceptors = [
			{ class : "#moduleMapping#.interceptors.AltchaGuard", name : "AltchaGuard@cbAltcha" }
		];
	}

}
