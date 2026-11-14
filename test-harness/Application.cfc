/**
 * Test harness: a minimal ColdBox app that loads cbAltcha from the package root.
 * The package folder must be named "cbAltcha" (the ColdBox module name is the folder name).
 */
component {

	this.name              = "cbAltcha-test-harness-" & hash( getCurrentTemplatePath() );
	this.sessionManagement = true;
	this.setClientCookies  = true;
	this.timezone          = "UTC";

	rootPath       = getDirectoryFromPath( getCurrentTemplatePath() );
	moduleRootPath = reReplaceNoCase( rootPath, "cbAltcha(\\|/)test-harness(\\|/)$", "" );

	this.mappings[ "/root" ]       = rootPath;
	this.mappings[ "/coldbox" ]    = rootPath & "coldbox";
	this.mappings[ "/testbox" ]    = rootPath & "testbox";
	// parent folder of the package: registerAndActivateModule( "cbAltcha", "moduleroot" )
	this.mappings[ "/moduleroot" ] = moduleRootPath;
	this.mappings[ "/cbAltcha" ]   = moduleRootPath & "cbAltcha";

	COLDBOX_APP_ROOT_PATH = rootPath;
	COLDBOX_APP_MAPPING   = "/root";
	COLDBOX_CONFIG_FILE   = "";
	COLDBOX_APP_KEY       = "";

	function onApplicationStart(){
		application.cbBootstrap = new coldbox.system.Bootstrap(
			COLDBOX_CONFIG_FILE,
			COLDBOX_APP_ROOT_PATH,
			COLDBOX_APP_KEY,
			COLDBOX_APP_MAPPING
		);
		application.cbBootstrap.loadColdbox();
		application.cbController.getModuleService().registerAndActivateModule( "cbAltcha", "moduleroot" );
		return true;
	}

	function onRequestStart( string targetPage ){
		if ( url.keyExists( "fwreinit" ) ) {
			applicationStop();
			return false;
		}
		application.cbBootstrap.onRequestStart( arguments.targetPage );
		return true;
	}

}
