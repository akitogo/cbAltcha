component {

	property name="altchaService" inject="AltchaService@cbAltcha";

	this.allowedMethods = { challenge : "GET", widget : "GET", i18n : "GET" };

	// Widget files shipped in includes/ (ALTCHA widget v3, MIT, see includes/LICENSE.txt)
	variables.LANGUAGES = [ "de" ];

	/**
	 * GET /altcha/challenge: a fresh signed challenge for <altcha-widget challenge="/altcha/challenge">
	 */
	function challenge( event, rc, prc ){
		event.setHTTPHeader( name = "Cache-Control", value = "no-store" );
		event.renderData( type = "json", data = altchaService.createChallenge() );
	}

	/**
	 * GET /altcha/widget/altcha.js: the widget (ES module, load with <script type="module">)
	 */
	function widget( event, rc, prc ){
		sendScript( event, "altcha.min.js" );
	}

	/**
	 * GET /altcha/widget/i18n/de.js: widget translations (load after altcha.js)
	 */
	function i18n( event, rc, prc ){
		var lang = reReplace( listFirst( event.getValue( "lang", "" ), "." ), "[^a-z]", "", "all" );
		if ( !arrayContains( variables.LANGUAGES, lang ) ) {
			event.setHTTPHeader( statusCode = 404, statusText = "Not Found" );
			return event.renderData( type = "plain", data = "", statusCode = 404 );
		}
		sendScript( event, "i18n/#lang#.js" );
	}

	/**
	 * Answers a request the AltchaGuard interceptor rejected (prc.altcha.reason)
	 */
	function rejected( event, rc, prc ){
		var reason = prc.altcha.reason ?: "missing";
		// one-argument getHTTPHeader(): same result, and matches ColdBox's mocked headers in tests
		var accept    = event.getHTTPHeader( "Accept" ) ?: "";
		var xrw       = event.getHTTPHeader( "X-Requested-With" ) ?: "";
		var wantsJSON = findNoCase( "json", accept ) || len( xrw );
		if ( wantsJSON ) {
			return event.renderData(
				type       = "json",
				data       = { "ok" : false, "errors" : [ "altcha" ], "reason" : reason },
				statusCode = 403
			);
		}
		event.renderData(
			type        = "html",
			statusCode  = 403,
			data        = "<!doctype html><meta charset=""utf-8""><title>403</title>" &
				"<p>Die Spam-Prüfung ist fehlgeschlagen. Bitte geht zurück und sendet das Formular erneut.</p>" &
				"<p>The spam check failed. Please go back and send the form again.</p>"
		);
	}

	/**
	 * Wrong HTTP method on a module route: 405 instead of an exception
	 */
	function onInvalidHTTPMethod( event, rc, prc, faultAction, eventArguments ){
		arguments.event.setHTTPHeader( name = "Allow", value = "GET" );
		arguments.event.renderData( type = "plain", data = "Method Not Allowed", statusCode = 405 );
	}

	private function sendScript( required event, required string file ){
		var path = getDirectoryFromPath( getCurrentTemplatePath() ) & "../includes/" & arguments.file;
		arguments.event.setHTTPHeader( name = "Cache-Control", value = "public, max-age=86400" );
		arguments.event.renderData(
			type        = "plain",
			data        = fileRead( path, "utf-8" ),
			contentType = "text/javascript; charset=utf-8"
		);
	}

}
