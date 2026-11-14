component {

	function configure(){
		coldbox = {
			appName                 : "cbAltcha test harness",
			reinitPassword          : "",
			handlersIndexAutoReload : true,
			defaultEvent            : "Main.index",
			exceptionHandler        : "",
			customErrorTemplate     : "",
			handlerCaching          : false,
			eventCaching            : false
		};

		environments = {};

		logBox = {
			appenders : { console : { class : "coldbox.system.logging.appenders.ConsoleAppender" } },
			root      : { levelmax : "WARN", appenders : "*" }
		};

		moduleSettings = {
			cbAltcha : {
				hmacSecret    : "test-secret-for-the-test-harness",
				// cheap challenges so specs solve them in milliseconds
				cost          : 10,
				counterMin    : 5,
				counterMax    : 15,
				excludeEvents : [ "^cbAltcha:", "^main\.excluded$" ]
			}
		};
	}

}
