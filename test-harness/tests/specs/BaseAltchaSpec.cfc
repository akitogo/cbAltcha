/**
 * Base for all cbAltcha specs: loads the harness app, registers the module from the package root
 * and offers a solver that works like the browser widget (brute-forces the counter).
 */
component extends="coldbox.system.testing.BaseTestCase" appMapping="/root" {

	function beforeAll(){
		super.beforeAll();
		var moduleService = getController().getModuleService();
		if ( !moduleService.isModuleRegistered( "cbAltcha" ) ) {
			moduleService.registerAndActivateModule( "cbAltcha", "moduleroot" );
		}
		variables.altcha   = getInstance( "AltchaService@cbAltcha" );
		variables.settings = getController().getModuleSettings( "cbAltcha" );
		// expose the internals the specs check against reference values
		for ( var method in [ "deriveKey", "passwordBytes", "canonicalJSON", "hmacHex" ] ) {
			makePublic( variables.altcha, method, "_" & method );
		}
	}

	/**
	 * Solve a challenge like the widget: try counters until the derived key starts with keyPrefix
	 *
	 * @return struct { counter, derivedKey }
	 */
	struct function solve( required struct challenge ){
		var p     = arguments.challenge.parameters;
		var nonce = binaryDecode( p.nonce, "hex" );
		var salt  = binaryDecode( p.salt, "hex" );
		for ( var counter = 0; counter <= 100000; counter++ ) {
			var key = lCase(
				binaryEncode(
					variables.altcha._deriveKey( p.algorithm, variables.altcha._passwordBytes( nonce, counter ), salt, p.cost, p.keyLength ),
					"hex"
				)
			);
			if ( left( key, len( p.keyPrefix ) ) == p.keyPrefix ) {
				return { "counter" : counter, "derivedKey" : key };
			}
		}
		throw( "No solution found" );
	}

	/**
	 * The form field value the widget submits: base64( JSON { challenge, solution } )
	 */
	string function encodePayload( required struct challenge, required struct solution ){
		return toBase64(
			serializeJSON( {
				"challenge" : {
					"parameters" : arguments.challenge.parameters,
					"signature"  : arguments.challenge.signature
				},
				"solution" : arguments.solution
			} ),
			"utf-8"
		);
	}

	/**
	 * A fresh, valid payload
	 */
	string function validPayload(){
		var challenge = variables.altcha.createChallenge();
		return encodePayload( challenge, solve( challenge ) );
	}

	/**
	 * Decode a payload, let a closure change it, encode it again
	 */
	string function tamper( required string payload, required function change ){
		var data = deserializeJSON( charsetEncode( binaryDecode( arguments.payload, "base64" ), "utf-8" ) );
		arguments.change( data );
		return toBase64( serializeJSON( data ), "utf-8" );
	}

}
