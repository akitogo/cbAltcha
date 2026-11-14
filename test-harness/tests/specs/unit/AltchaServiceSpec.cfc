/**
 * AltchaService: key derivation, signing, challenge creation, verification
 *
 * Reference values come from Node's crypto (pbkdf2Sync, createHash, createHmac) and RFC 7914,
 * i.e. from an implementation independent of this module.
 */
component extends="tests.specs.BaseAltchaSpec" {

	variables.NONCE = "000102030405060708090a0b0c0d0e0f";
	variables.SALT  = "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff";

	function run(){
		describe( "Key derivation (reference values from Node's crypto)", () => {
			it( "matches the RFC 7914 PBKDF2-HMAC-SHA256 test vector (2 blocks)", () => {
				var key = altcha._deriveKey(
					"PBKDF2/SHA-256",
					charsetDecode( "passwd", "utf-8" ),
					charsetDecode( "salt", "utf-8" ),
					1,
					64
				);
				expect( lCase( binaryEncode( key, "hex" ) ) ).toBe(
					"55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783"
				);
			} );

			it( "derives PBKDF2/SHA-256 from a binary password (nonce + uint32 counter)", () => {
				expect( derive( "PBKDF2/SHA-256", 100, 32 ) ).toBe( "6604d2faf089e6a235d70147a61ac76bedf953fa578f485a03da29664f93da03" );
			} );

			it( "derives multi-block PBKDF2/SHA-256 keys", () => {
				expect( derive( "PBKDF2/SHA-256", 100, 64 ) ).toBe(
					"6604d2faf089e6a235d70147a61ac76bedf953fa578f485a03da29664f93da0393f8b59e090942dbfa9467e5f1154dc03266c3c5cf0d7d54482cd9cb1c5e1de0"
				);
			} );

			it( "derives PBKDF2/SHA-512 keys truncated to keyLength", () => {
				expect( derive( "PBKDF2/SHA-512", 100, 32 ) ).toBe( "c2544bd688912d44500e4fe7e636fc66e03c4c4601e281bbc70698adadd14241" );
			} );

			it( "derives iterated SHA-256 keys", () => {
				expect( derive( "SHA-256", 100, 32 ) ).toBe( "f271cf4ab195deede8c4b88b89da7e9775cead91f121774c1d40dbd763f83782" );
			} );

			it( "derives iterated SHA-512 keys truncated to keyLength", () => {
				expect( derive( "SHA-512", 3, 32 ) ).toBe( "dc37c495142758d649c1c392daf2e4dfe896f70c144458629927e6f0fb1f5e0c" );
			} );
		} );

		describe( "Signing", () => {
			it( "serializes parameters like JSON.stringify with sorted keys", () => {
				expect( altcha._canonicalJSON( sampleParameters() ) ).toBe(
					"{""algorithm"":""PBKDF2/SHA-256"",""cost"":2000,""expiresAt"":1800000000,""keyLength"":32,""keyPrefix"":""dd"",""keySignature"":""cc"",""nonce"":""bb"",""salt"":""aa""}"
				);
			} );

			it( "signs with HMAC-SHA256 like altcha-lib", () => {
				expect( altcha._hmacHex( "test-secret", altcha._canonicalJSON( sampleParameters() ) ) ).toBe(
					"d20cbac7d67662b5998e93c5cbc8a714af07b9192e91a32c1ddb59a02abc3ebf"
				);
			} );
		} );

		describe( "createChallenge()", () => {
			it( "returns signed parameters in the widget's format", () => {
				var challenge = altcha.createChallenge();
				var p         = challenge.parameters;
				var now       = int( createObject( "java", "java.lang.System" ).currentTimeMillis() / 1000 );

				expect( challenge ).toHaveKey( "parameters" ).toHaveKey( "signature" );
				expect( structKeyList( p ).listSort( "textnocase" ) ).toBe(
					"algorithm,cost,expiresAt,keyLength,keyPrefix,keySignature,nonce,salt"
				);
				expect( p.algorithm ).toBe( settings.algorithm );
				expect( p.cost ).toBe( settings.cost );
				expect( p.keyLength ).toBe( 32 );
				expect( p.expiresAt ).toBeBetween( now + settings.expires - 5, now + settings.expires + 5 );
				expect( p.nonce ).toMatch( "^[0-9a-f]{32}$" );
				expect( p.salt ).toMatch( "^[0-9a-f]{32}$" );
				expect( p.keyPrefix ).toMatch( "^[0-9a-f]{32}$" );
				expect( p.keySignature ).toMatch( "^[0-9a-f]{64}$" );
				expect( challenge.signature ).toBe( altcha._hmacHex( settings.hmacSecret, altcha._canonicalJSON( p ) ) );
			} );

			it( "uses a fresh nonce and salt every time", () => {
				var a = altcha.createChallenge().parameters;
				var b = altcha.createChallenge().parameters;
				expect( a.nonce ).notToBe( b.nonce );
				expect( a.salt ).notToBe( b.salt );
			} );

			it( "is solvable with a counter between counterMin and counterMax", () => {
				var solution = solve( altcha.createChallenge() );
				expect( solution.counter ).toBeBetween( settings.counterMin, settings.counterMax );
			} );
		} );

		describe( "verify()", () => {
			it( "accepts a valid solution", () => {
				var result = altcha.verify( validPayload() );
				expect( result.verified ).toBeTrue();
				expect( result.reason ).toBe( "" );
			} );

			it( "accepts a solution only once", () => {
				var payload = validPayload();
				expect( altcha.verify( payload ).verified ).toBeTrue();
				var again = altcha.verify( payload );
				expect( again.verified ).toBeFalse();
				expect( again.reason ).toBe( "replayed" );
			} );

			it( "rejects a missing payload", () => {
				expect( altcha.verify( "" ).reason ).toBe( "missing" );
				expect( altcha.verify( "   " ).reason ).toBe( "missing" );
			} );

			it( "rejects payloads that are not base64 JSON in the widget's shape", () => {
				expect( altcha.verify( "not base64!" ).reason ).toBe( "malformed" );
				expect( altcha.verify( toBase64( "not json", "utf-8" ) ).reason ).toBe( "malformed" );
				expect( altcha.verify( toBase64( "[1,2]", "utf-8" ) ).reason ).toBe( "malformed" );
				expect( altcha.verify( toBase64( "{""challenge"":{}}", "utf-8" ) ).reason ).toBe( "malformed" );
			} );

			it( "rejects parameters it never issues", () => {
				var payload = tamper( validPayload(), ( data ) => data.challenge.parameters[ "data" ] = "x" );
				expect( altcha.verify( payload ).reason ).toBe( "malformed" );
			} );

			it( "rejects parameters with the wrong type", () => {
				var payload = tamper( validPayload(), ( data ) => data.challenge.parameters.nonce = "not hex" );
				expect( altcha.verify( payload ).reason ).toBe( "malformed" );
				payload = tamper( validPayload(), ( data ) => data.challenge.parameters.cost = "abc" );
				expect( altcha.verify( payload ).reason ).toBe( "malformed" );
			} );

			it( "rejects expired challenges", () => {
				var expires = settings.expires;
				settings.expires = -60;
				try {
					var challenge = altcha.createChallenge();
				} finally {
					settings.expires = expires;
				}
				expect( altcha.verify( encodePayload( challenge, solve( challenge ) ) ).reason ).toBe( "expired" );
			} );

			it( "rejects tampered parameters", () => {
				var payload = tamper( validPayload(), ( data ) => data.challenge.parameters.cost = 1 );
				expect( altcha.verify( payload ).reason ).toBe( "signature" );
			} );

			it( "rejects challenges signed with another secret", () => {
				var challenge = altcha.createChallenge();
				var solution  = solve( challenge );
				challenge.signature = altcha._hmacHex( "another-secret", altcha._canonicalJSON( challenge.parameters ) );
				expect( altcha.verify( encodePayload( challenge, solution ) ).reason ).toBe( "signature" );
			} );

			it( "rejects a wrong derived key", () => {
				var payload = tamper( validPayload(), ( data ) => {
					var key = data.solution.derivedKey;
					data.solution.derivedKey = ( left( key, 1 ) == "0" ? "1" : "0" ) & mid( key, 2, len( key ) );
				} );
				expect( altcha.verify( payload ).reason ).toBe( "solution" );
			} );

			it( "rejects the derived key of another challenge", () => {
				var challenge = altcha.createChallenge();
				var other     = solve( altcha.createChallenge() );
				expect( altcha.verify( encodePayload( challenge, other ) ).reason ).toBe( "solution" );
			} );

			it( "rejects malformed solutions", () => {
				var payload = tamper( validPayload(), ( data ) => data.solution.derivedKey = uCase( data.solution.derivedKey ) );
				expect( altcha.verify( payload ).reason ).toBe( "solution" );
				payload = tamper( validPayload(), ( data ) => data.solution.counter = -1 );
				expect( altcha.verify( payload ).reason ).toBe( "solution" );
				payload = tamper( validPayload(), ( data ) => data.solution.counter = 4294967296 );
				expect( altcha.verify( payload ).reason ).toBe( "solution" );
				payload = tamper( validPayload(), ( data ) => structDelete( data.solution, "derivedKey" ) );
				expect( altcha.verify( payload ).reason ).toBe( "solution" );
			} );
		} );
	}

	/* ---------------------------------------------------------------------------------- */

	private string function derive( required string algorithm, required numeric cost, required numeric keyLength ){
		var key = altcha._deriveKey(
			arguments.algorithm,
			altcha._passwordBytes( binaryDecode( variables.NONCE, "hex" ), 1234 ),
			binaryDecode( variables.SALT, "hex" ),
			arguments.cost,
			arguments.keyLength
		);
		return lCase( binaryEncode( key, "hex" ) );
	}

	private struct function sampleParameters(){
		return {
			"salt"         : "aa",
			"nonce"        : "bb",
			"keySignature" : "cc",
			"keyPrefix"    : "dd",
			"keyLength"    : 32,
			"expiresAt"    : 1800000000,
			"cost"         : 2000,
			"algorithm"    : "PBKDF2/SHA-256"
		};
	}

}
