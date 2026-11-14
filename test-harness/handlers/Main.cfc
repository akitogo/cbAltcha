/**
 * Endpoints the specs post to
 */
component {

	function index( event, rc, prc ){
		return "cbAltcha test harness";
	}

	/**
	 * Test form for the browser specs (e2e/): the real widget, posting natively to /submit.
	 * ?auto=onfocus|onsubmit selects the widget mode, ?lang=de loads the German texts.
	 * (Not named "form": that is the CFML form scope.)
	 */
	function widgetForm( event, rc, prc ){
		var auto = listFindNoCase( "onfocus,onsubmit", event.getValue( "auto", "" ) ) ? lCase( rc.auto ) : "onfocus";
		var lang = event.getValue( "lang", "" ) == "de" ? "de" : "en";
		return "<!doctype html><html lang=""#lang#""><head><meta charset=""utf-8""><title>cbAltcha form</title>" &
			"<script type=""module"" src=""/altcha/widget/altcha.js""></script>" &
			( lang == "de" ? "<script type=""module"" src=""/altcha/widget/i18n/de.js""></script>" : "" ) &
			"</head><body>" &
			"<form id=""form"" method=""post"" action=""/submit"">" &
			"<label for=""name"">Name</label> <input id=""name"" name=""name"" required>" &
			"<altcha-widget name=""altcha"" challenge=""/altcha/challenge"" auto=""#auto#"" language=""#lang#""></altcha-widget>" &
			"<button id=""send"" type=""submit"">Send</button>" &
			"</form></body></html>";
	}

	// protected by the AltchaGuard interceptor (POST/PUT/PATCH/DELETE)
	function submit( event, rc, prc ){
		prc.submitted = true;
		return "submitted: " & encodeForHTML( event.getValue( "name", "" ) );
	}

	// excluded via moduleSettings.cbAltcha.excludeEvents
	function excluded( event, rc, prc ){
		prc.submitted = true;
		return "excluded";
	}

}
