/**
 * Requires a valid ALTCHA solution on every protected request.
 *
 * A request is protected when
 * - its HTTP method is in settings.methods (POST, PUT, PATCH, DELETE), and
 * - its event matches settings.includeEvents (or includeEvents is empty), and
 * - its event matches none of settings.excludeEvents.
 *
 * Invalid or missing solutions are answered by settings.rejectEvent (403); the original
 * event never runs. On success the payload field is removed from rc.
 */
component {

	property name="settings" inject="coldbox:moduleSettings:cbAltcha";
	property name="altchaService" inject="AltchaService@cbAltcha";
	property name="log" inject="logbox:logger:{this}";

	function preProcess( event, data, buffer, rc, prc ){
		if ( !variables.settings.enabled || !isProtected( arguments.event ) ) {
			return;
		}

		var field  = variables.settings.fieldName;
		var result = variables.altchaService.verify( toString( arguments.event.getValue( field, "" ) ) );
		arguments.event.removeValue( field );

		if ( result.verified ) {
			return;
		}

		log.info(
			"ALTCHA rejected #arguments.event.getHTTPMethod()# #arguments.event.getCurrentEvent()#: #result.reason#"
		);
		arguments.prc.altcha = { "reason" : result.reason, "event" : arguments.event.getCurrentEvent() };
		arguments.event.overrideEvent( variables.settings.rejectEvent );
	}

	/**
	 * Does this request need a solution?
	 */
	boolean function isProtected( required event ){
		if ( !arrayContainsNoCase( variables.settings.methods, arguments.event.getHTTPMethod() ) ) {
			return false;
		}
		var name = arguments.event.getCurrentEvent();
		for ( var pattern in variables.settings.excludeEvents ) {
			if ( reFindNoCase( pattern, name ) ) {
				return false;
			}
		}
		if ( !arrayLen( variables.settings.includeEvents ) ) {
			return true;
		}
		for ( var pattern in variables.settings.includeEvents ) {
			if ( reFindNoCase( pattern, name ) ) {
				return true;
			}
		}
		return false;
	}

}
