/**
 * Endpoints the specs post to
 */
component {

	function index( event, rc, prc ){
		return "cbAltcha test harness";
	}

	// protected by the AltchaGuard interceptor (POST/PUT/PATCH/DELETE)
	function submit( event, rc, prc ){
		prc.submitted = true;
		return "submitted";
	}

	// excluded via moduleSettings.cbAltcha.excludeEvents
	function excluded( event, rc, prc ){
		prc.submitted = true;
		return "excluded";
	}

}
