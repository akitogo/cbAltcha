/**
 * AltchaGuard interceptor and the module's routes, through real ColdBox requests
 */
component extends="tests.specs.BaseAltchaSpec" {

	function run(){
		describe( "GET /altcha/challenge", () => {
			beforeEach( () => setup() );

			it( "returns a signed challenge as JSON", () => {
				var event = get( route = "/altcha/challenge" );
				var data  = event.getRenderData();
				expect( data.type ).toBe( "json" );
				expect( data.data ).toHaveKey( "parameters" ).toHaveKey( "signature" );
				expect( data.data.parameters.algorithm ).toBe( settings.algorithm );
			} );

			it( "is never checked by the interceptor, and answers other methods with 405", () => {
				var event = post( route = "/altcha/challenge" );
				expect( event.getCurrentEvent() ).notToBe( settings.rejectEvent );
				expect( event.getRenderData().statusCode ).toBe( 405 );
			} );
		} );

		describe( "Widget files", () => {
			beforeEach( () => setup() );

			it( "serves the widget as JavaScript", () => {
				var data = get( route = "/altcha/widget/altcha.js" ).getRenderData();
				expect( data.contentType ).toInclude( "text/javascript" );
				expect( len( data.data ) ).toBeGT( 100000 );
			} );

			it( "serves the German translations", () => {
				var data = get( route = "/altcha/widget/i18n/de.js" ).getRenderData();
				expect( data.contentType ).toInclude( "text/javascript" );
				expect( data.data ).toInclude( "Ich bin kein Roboter" );
			} );

			it( "answers 404 for unknown languages", () => {
				expect( get( route = "/altcha/widget/i18n/xx.js" ).getRenderData().statusCode ).toBe( 404 );
			} );
		} );

		describe( "Protected requests", () => {
			beforeEach( () => setup() );

			it( "runs the event with a valid solution and removes the field from rc", () => {
				var event = post( route = "/submit", params = { "altcha" : validPayload(), "name" : "Test" } );
				expect( event.getCurrentEvent() ).toBe( "main.submit" );
				expect( event.getPrivateValue( "submitted", false ) ).toBeTrue();
				expect( event.valueExists( "altcha" ) ).toBeFalse();
				expect( event.getValue( "name" ) ).toBe( "Test" );
			} );

			it( "rejects a missing solution with 403 and never runs the event", () => {
				var event = post( route = "/submit" );
				expect( event.getCurrentEvent() ).toBe( settings.rejectEvent );
				expect( event.getPrivateValue( "submitted", false ) ).toBeFalse();
				expect( event.getRenderData().statusCode ).toBe( 403 );
				expect( event.getPrivateValue( "altcha" ).reason ).toBe( "missing" );
			} );

			it( "answers JSON when the request asks for it", () => {
				var data = post( route = "/submit", headers = { "Accept" : "application/json" } ).getRenderData();
				expect( data.type ).toBe( "json" );
				expect( data.statusCode ).toBe( 403 );
				expect( data.data.ok ).toBeFalse();
				expect( data.data.errors ).toBe( [ "altcha" ] );
				expect( data.data.reason ).toBe( "missing" );
			} );

			it( "answers HTML otherwise", () => {
				var data = post( route = "/submit" ).getRenderData();
				expect( data.type ).toBe( "html" );
				expect( data.statusCode ).toBe( 403 );
			} );

			it( "rejects a replayed solution", () => {
				var payload = validPayload();
				expect( post( route = "/submit", params = { "altcha" : payload } ).getCurrentEvent() ).toBe( "main.submit" );
				setup();
				var event = post( route = "/submit", params = { "altcha" : payload } );
				expect( event.getCurrentEvent() ).toBe( settings.rejectEvent );
				expect( event.getPrivateValue( "altcha" ).reason ).toBe( "replayed" );
			} );

			it( "checks PUT, PATCH and DELETE too", () => {
				for ( var method in [ "PUT", "PATCH", "DELETE" ] ) {
					setup();
					var event = this.request( route = "/submit", method = method );
					expect( event.getCurrentEvent() ).toBe( settings.rejectEvent, method );
				}
			} );

			it( "does not check GET requests", () => {
				var event = get( route = "/submit" );
				expect( event.getCurrentEvent() ).toBe( "main.submit" );
				expect( event.getPrivateValue( "submitted", false ) ).toBeTrue();
			} );
		} );

		describe( "Rules", () => {
			beforeEach( () => setup() );

			it( "does not check excluded events", () => {
				var event = post( route = "/excluded" );
				expect( event.getCurrentEvent() ).toBe( "main.excluded" );
				expect( event.getPrivateValue( "submitted", false ) ).toBeTrue();
			} );

			it( "checks only included events when includeEvents is set", () => {
				var original = settings.includeEvents;
				settings.includeEvents = [ "^main\.other$" ];
				try {
					expect( post( route = "/submit" ).getCurrentEvent() ).toBe( "main.submit" );
					setup();
					settings.includeEvents = [ "^main\.submit$" ];
					expect( post( route = "/submit" ).getCurrentEvent() ).toBe( settings.rejectEvent );
				} finally {
					settings.includeEvents = original;
				}
			} );

			it( "checks nothing when disabled", () => {
				settings.enabled = false;
				try {
					expect( post( route = "/submit" ).getCurrentEvent() ).toBe( "main.submit" );
				} finally {
					settings.enabled = true;
				}
			} );
		} );
	}

}
