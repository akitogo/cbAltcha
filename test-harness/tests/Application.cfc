component {

	this.name              = "cbAltcha-tests-" & hash( getCurrentTemplatePath() );
	this.sessionManagement = true;
	this.setClientCookies  = true;
	this.timezone          = "UTC";

	testsPath      = getDirectoryFromPath( getCurrentTemplatePath() );
	rootPath       = reReplaceNoCase( testsPath, "tests(\\|/)$", "" );
	moduleRootPath = reReplaceNoCase( rootPath, "cbAltcha(\\|/)test-harness(\\|/)$", "" );

	this.mappings[ "/tests" ]      = testsPath;
	this.mappings[ "/root" ]       = rootPath;
	this.mappings[ "/coldbox" ]    = rootPath & "coldbox";
	this.mappings[ "/testbox" ]    = rootPath & "testbox";
	this.mappings[ "/moduleroot" ] = moduleRootPath;
	this.mappings[ "/cbAltcha" ]   = moduleRootPath & "cbAltcha";

	function onRequestEnd(){
		structDelete( application, "cbController" );
		structDelete( application, "wirebox" );
	}

}
