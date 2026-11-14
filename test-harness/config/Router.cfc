component {

	function configure(){
		route( "/submit", "main.submit" );
		route( "/excluded", "main.excluded" );
		route( "/", "main.index" );
	}

}
