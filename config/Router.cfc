/**
 * Routes under the module entry point /altcha
 */
component {

	function configure(){
		get( "/challenge", "main.challenge" );
		// Widget files: /altcha/widget/altcha.js, /altcha/widget/i18n/de.js
		get( "/widget/i18n/:lang", "main.i18n" );
		get( "/widget/altcha.js", "main.widget" );
	}

}
