/**
 * ALTCHA v2 protocol (as implemented by altcha-lib 2.x, used by the ALTCHA widget v3)
 *
 * Challenge (JSON sent to the widget):
 *   { "parameters": { algorithm, cost, expiresAt, keyLength, keyPrefix, keySignature, nonce, salt },
 *     "signature": hex( HMAC-SHA256( hmacSecret, canonicalJSON( parameters ) ) ) }
 *
 *   nonce, salt     16 random bytes, hex
 *   password        nonce bytes + counter as big-endian uint32
 *   derivedKey      KDF( password, salt, cost, keyLength )   (PBKDF2/SHA-256 or iterated SHA-256)
 *   keyPrefix       first keyLength/2 bytes of the derived key for a secret random counter (hex)
 *   keySignature    hex( HMAC-SHA256( keySecret, derivedKey ) )
 *
 * The browser brute-forces counters until KDF(...) starts with keyPrefix and submits
 *   base64( JSON { challenge: { parameters, signature }, solution: { counter, derivedKey, time } } )
 *
 * Verification: expiry, signature over the parameters, then HMAC of the submitted derived key
 * against keySignature (no key derivation needed), and finally single use.
 */
component singleton accessors="true" {

	property name="settings" inject="coldbox:moduleSettings:cbAltcha";
	property name="cachebox" inject="cachebox";
	property name="log" inject="logbox:logger:{this}";

	// Parameter names we issue and accept, in canonical (sorted) order
	variables.PARAMETER_KEYS = [ "algorithm", "cost", "expiresAt", "keyLength", "keyPrefix", "keySignature", "nonce", "salt" ];
	variables.ALGORITHMS = {
		"PBKDF2/SHA-256" : { type : "pbkdf2", mac : "HmacSHA256", digestLength : 32 },
		"PBKDF2/SHA-384" : { type : "pbkdf2", mac : "HmacSHA384", digestLength : 48 },
		"PBKDF2/SHA-512" : { type : "pbkdf2", mac : "HmacSHA512", digestLength : 64 },
		"SHA-256"        : { type : "sha", digest : "SHA-256" },
		"SHA-384"        : { type : "sha", digest : "SHA-384" },
		"SHA-512"        : { type : "sha", digest : "SHA-512" }
	};
	variables.KEY_LENGTH = 32;
	variables.MAX_UINT32 = 4294967295;

	function onDIComplete(){
		variables.secureRandom = createObject( "java", "java.security.SecureRandom" ).init();
		if ( !len( variables.settings.hmacSecret ) ) {
			variables.settings.hmacSecret = binaryEncode( randomBytes( 32 ), "hex" );
			log.warn( "ALTCHA_HMAC_SECRET is not set: using a random secret until the application restarts." );
		}
		if ( !structKeyExists( variables.ALGORITHMS, variables.settings.algorithm ) ) {
			throw( type = "Altcha.InvalidSetting", message = "Unsupported algorithm: #variables.settings.algorithm#" );
		}
		// Second secret for key signatures, derived so only one secret has to be configured
		variables.keySecret = hmacHex( variables.settings.hmacSecret, "altcha-key-signature" );
	}

	/**
	 * Create a signed challenge for the widget
	 *
	 * @return struct { parameters, signature } ready for JSON serialization
	 */
	struct function createChallenge(){
		var counter = variables.settings.counterMin + variables.secureRandom.nextInt(
			javacast( "int", variables.settings.counterMax - variables.settings.counterMin + 1 )
		);
		var nonce   = randomBytes( 16 );
		var salt    = randomBytes( 16 );
		var derived = deriveKey(
			variables.settings.algorithm,
			passwordBytes( nonce, counter ),
			salt,
			variables.settings.cost,
			variables.KEY_LENGTH
		);

		var parameters = {
			"algorithm"    : variables.settings.algorithm,
			"cost"         : javacast( "long", variables.settings.cost ),
			"expiresAt"    : javacast( "long", nowSeconds() + variables.settings.expires ),
			"keyLength"    : javacast( "long", variables.KEY_LENGTH ),
			// first keyLength/2 bytes, like altcha-lib's default keyPrefixLength
			"keyPrefix"    : left( lCase( binaryEncode( derived, "hex" ) ), variables.KEY_LENGTH ),
			"keySignature" : hmacHex( variables.keySecret, derived ),
			"nonce"        : lCase( binaryEncode( nonce, "hex" ) ),
			"salt"         : lCase( binaryEncode( salt, "hex" ) )
		};

		return {
			"parameters" : parameters,
			"signature"  : hmacHex( variables.settings.hmacSecret, canonicalJSON( parameters ) )
		};
	}

	/**
	 * Verify a submitted widget payload. A valid payload is accepted only once.
	 *
	 * @payload The value of the form field (base64 JSON)
	 *
	 * @return struct { verified : boolean, reason : "" | missing | malformed | expired | signature | solution | replayed }
	 */
	struct function verify( string payload = "" ){
		if ( !len( trim( arguments.payload ) ) ) {
			return result( "missing" );
		}

		// 1. Decode and check the shape
		try {
			var data = deserializeJSON( charsetEncode( binaryDecode( trim( arguments.payload ), "base64" ), "utf-8" ) );
		} catch ( any e ) {
			return result( "malformed" );
		}
		if (
			!isStruct( data ) || !structKeyExists( data, "challenge" ) || !isStruct( data.challenge ) ||
			!structKeyExists( data, "solution" ) || !isStruct( data.solution ) ||
			!structKeyExists( data.challenge, "parameters" ) || !isStruct( data.challenge.parameters ) ||
			!structKeyExists( data.challenge, "signature" ) || !isSimpleValue( data.challenge.signature )
		) {
			return result( "malformed" );
		}
		var parameters = normalizeParameters( data.challenge.parameters );
		if ( isNull( parameters ) ) {
			return result( "malformed" );
		}
		var signature = lCase( data.challenge.signature );
		if ( !reFind( "^[0-9a-f]{64,128}$", signature ) ) {
			return result( "malformed" );
		}

		// 2. Expiry
		if ( parameters.expiresAt < nowSeconds() ) {
			return result( "expired" );
		}

		// 3. Signature over the parameters (tamper check)
		if ( !constantTimeEqual( signature, hmacHex( variables.settings.hmacSecret, canonicalJSON( parameters ) ) ) ) {
			return result( "signature" );
		}

		// 4. Solution: the derived key must match the signed key signature
		var solution = data.solution;
		if (
			!structKeyExists( solution, "derivedKey" ) || !isSimpleValue( solution.derivedKey ) ||
			!reFind( "^(?:[0-9a-f]{2})+$", solution.derivedKey ) ||
			!structKeyExists( solution, "counter" ) || !isValid( "integer", solution.counter ) ||
			solution.counter < 0 || solution.counter > variables.MAX_UINT32
		) {
			return result( "solution" );
		}
		if (
			!constantTimeEqual(
				parameters.keySignature,
				hmacHex( variables.keySecret, binaryDecode( solution.derivedKey, "hex" ) )
			)
		) {
			return result( "solution" );
		}

		// 5. Single use: remember the challenge until it expires
		if ( !markUsed( signature, parameters.expiresAt ) ) {
			return result( "replayed" );
		}

		return result( "" );
	}

	/* ---------------------------------------------------------------------------------- */

	private struct function result( required string reason ){
		return { "verified" : !len( arguments.reason ), "reason" : arguments.reason };
	}

	/**
	 * Accept only the parameters we issue, with the expected types. Returns null if anything is off.
	 */
	private any function normalizeParameters( required struct input ){
		if ( structCount( arguments.input ) != arrayLen( variables.PARAMETER_KEYS ) ) {
			return;
		}
		var p = {};
		for ( var key in variables.PARAMETER_KEYS ) {
			if ( !structKeyExists( arguments.input, key ) || !isSimpleValue( arguments.input[ key ] ) ) {
				return;
			}
			p[ key ] = arguments.input[ key ];
		}
		if ( !structKeyExists( variables.ALGORITHMS, p.algorithm ) ) {
			return;
		}
		for ( var key in [ "cost", "expiresAt", "keyLength" ] ) {
			if ( !isValid( "integer", p[ key ] ) || p[ key ] < 1 ) {
				return;
			}
			p[ key ] = javacast( "long", p[ key ] );
		}
		for ( var key in [ "keyPrefix", "keySignature", "nonce", "salt" ] ) {
			if ( !reFind( "^[0-9a-f]+$", p[ key ] ) ) {
				return;
			}
		}
		return p;
	}

	/**
	 * JSON.stringify of the parameters with sorted keys, exactly as altcha-lib signs them.
	 * Only called with normalized parameters (hex strings, known algorithm names, integers).
	 */
	private string function canonicalJSON( required struct parameters ){
		var parts = [];
		for ( var key in variables.PARAMETER_KEYS ) {
			var value = arguments.parameters[ key ];
			if ( key == "cost" || key == "expiresAt" || key == "keyLength" ) {
				arrayAppend( parts, """#key#"":#javacast( "long", value ).toString()#" );
			} else {
				arrayAppend( parts, """#key#"":""#value#""" );
			}
		}
		return "{" & arrayToList( parts, "," ) & "}";
	}

	/**
	 * Remember a used challenge. Returns false if it was already used.
	 */
	private boolean function markUsed( required string signature, required numeric expiresAt ){
		var cache = variables.cachebox.getCache( variables.settings.cacheName );
		var key   = "altcha-used-" & arguments.signature;
		lock name="altcha-#arguments.signature#" type="exclusive" timeout="5" {
			if ( cache.lookup( key ) ) {
				return false;
			}
			var minutes = max( 1, ceiling( ( arguments.expiresAt - nowSeconds() ) / 60 ) + 1 );
			cache.set( key, true, minutes, 0 );
		}
		return true;
	}

	/**
	 * Key derivation as in altcha-lib/algorithms/pbkdf2 and /sha
	 */
	private any function deriveKey(
		required string algorithm,
		required any password,
		required any salt,
		required numeric cost,
		required numeric keyLength
	){
		var spec = variables.ALGORITHMS[ arguments.algorithm ];
		if ( spec.type == "sha" ) {
			var md   = createObject( "java", "java.security.MessageDigest" ).getInstance( spec.digest );
			var data = concatBytes( arguments.salt, arguments.password );
			for ( var i = 1; i <= max( 1, arguments.cost ); i++ ) {
				data = md.digest( data );
			}
			return copyBytes( data, arguments.keyLength );
		}
		return pbkdf2( spec, arguments.password, arguments.salt, arguments.cost, arguments.keyLength );
	}

	/**
	 * PBKDF2 (RFC 8018) with an HMAC on raw password bytes. Java's PBKDF2WithHmac* takes a
	 * char[] password, which cannot represent arbitrary bytes, so the loop is done here.
	 */
	private any function pbkdf2(
		required struct spec,
		required any password,
		required any salt,
		required numeric iterations,
		required numeric keyLength
	){
		var mac = createObject( "java", "javax.crypto.Mac" ).getInstance( arguments.spec.mac );
		mac.init( createObject( "java", "javax.crypto.spec.SecretKeySpec" ).init( arguments.password, arguments.spec.mac ) );
		var blocks = ceiling( arguments.keyLength / arguments.spec.digestLength );
		var out    = createObject( "java", "java.io.ByteArrayOutputStream" ).init();
		var BigInteger = createObject( "java", "java.math.BigInteger" );
		for ( var b = 1; b <= blocks; b++ ) {
			mac.update( arguments.salt );
			mac.update( createObject( "java", "java.nio.ByteBuffer" ).allocate( 4 ).putInt( javacast( "int", b ) ).array() );
			var u = mac.doFinal();
			var t = BigInteger.init( 1, u );
			for ( var i = 2; i <= arguments.iterations; i++ ) {
				u = mac.doFinal( u );
				t = t.xor( BigInteger.init( 1, u ) );
			}
			out.write( toFixedBytes( t, arguments.spec.digestLength ) );
		}
		return copyBytes( out.toByteArray(), arguments.keyLength );
	}

	/** nonce + counter as big-endian uint32 (altcha-lib "uint32" counter mode) */
	private any function passwordBytes( required any nonce, required numeric counter ){
		var buffer = createObject( "java", "java.nio.ByteBuffer" ).allocate( arrayLen( arguments.nonce ) + 4 );
		buffer.put( arguments.nonce );
		buffer.putInt( javacast( "int", arguments.counter ) );
		return buffer.array();
	}

	private string function hmacHex( required string secret, required any data ){
		var mac = createObject( "java", "javax.crypto.Mac" ).getInstance( "HmacSHA256" );
		mac.init(
			createObject( "java", "javax.crypto.spec.SecretKeySpec" ).init( charsetDecode( arguments.secret, "utf-8" ), "HmacSHA256" )
		);
		var bytes = isBinary( arguments.data ) ? arguments.data : charsetDecode( arguments.data, "utf-8" );
		return lCase( binaryEncode( mac.doFinal( bytes ), "hex" ) );
	}

	private boolean function constantTimeEqual( required string a, required string b ){
		return createObject( "java", "java.security.MessageDigest" ).isEqual(
			charsetDecode( arguments.a, "utf-8" ),
			charsetDecode( arguments.b, "utf-8" )
		);
	}

	private any function randomBytes( required numeric count ){
		// generateSecretKey uses a SecureRandom; AES-128 = 16 bytes, AES-256 = 32 bytes
		return binaryDecode( generateSecretKey( "AES", arguments.count * 8 ), "base64" );
	}

	private any function concatBytes( required any a, required any b ){
		var out = createObject( "java", "java.io.ByteArrayOutputStream" ).init();
		out.write( arguments.a );
		out.write( arguments.b );
		return out.toByteArray();
	}

	private any function copyBytes( required any bytes, required numeric length ){
		return createObject( "java", "java.util.Arrays" ).copyOf( arguments.bytes, javacast( "int", arguments.length ) );
	}

	/** BigInteger -> exactly n bytes (drops the sign byte, left-pads with zeros) */
	private any function toFixedBytes( required any bigInt, required numeric n ){
		var raw = arguments.bigInt.toByteArray();
		var len = arrayLen( raw );
		if ( len == arguments.n ) {
			return raw;
		}
		var out = createObject( "java", "java.nio.ByteBuffer" ).allocate( javacast( "int", arguments.n ) );
		if ( len > arguments.n ) {
			out.put( raw, javacast( "int", len - arguments.n ), javacast( "int", arguments.n ) );
		} else {
			out.position( javacast( "int", arguments.n - len ) );
			out.put( raw );
		}
		return out.array();
	}

	private numeric function nowSeconds(){
		return int( createObject( "java", "java.lang.System" ).currentTimeMillis() / 1000 );
	}

}
