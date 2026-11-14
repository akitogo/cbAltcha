component {

	function configure(){
		route( "/form", "main.widgetForm" );
		route( "/submit", "main.submit" );
		route( "/excluded", "main.excluded" );
		route( "/", "main.index" );
	}

}
