<cfsetting showDebugOutput="false">
<cfparam name="url.reporter" default="simple">
<cfparam name="url.directory" default="tests.specs">
<cfparam name="url.recurse" default="true" type="boolean">
<cfoutput>#new testbox.system.TestBox( directory = { mapping : url.directory, recurse : url.recurse } ).run( reporter = url.reporter )#</cfoutput>
