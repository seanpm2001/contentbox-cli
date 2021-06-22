/**
 * A CLI based ContentBox installer. This is an automated approac to installing ContentBox.
 * If you want a wizard like setup then use the `install-wizard` command.
 * .
 * {code:bash}
 * contentbox install name=MySite cfmlEngine=lucee@5 database=mysql username=root password=password
 * {code}
 *
 **/
 component {

	// DI
	property name="settings" inject="box:modulesettings:contentbox-cli";

	static {
		engines = [ "lucee@5", "adobe@2016", "adobe@2018", "adobe@2021" ];
		databases = [ "HyperSonicSQL", "MySQL5", "MySQL8", "MicrosoftSQL", "PostgreSQL", "Oracle" ];
	};

	/**
	 * Install a ContentBox instance on the current working directory
	 *
	 * @name The name of the site to build
	 * @cfmlEngine The CFML engine to bind the installed ContentBox instance to
	 * @cfmlEngine.optionsUDF completeEngines
	 * @cfmlPassword The password to root the CFML admin with
	 * @coldboxPassword The password to root the ColdBox app with
	 * @databaseType The type of database you will be using
	 * @databaseType.optionsUDF completeDatabases
	 * @databaseHost The database host to use, leave empty to use localhost
	 * @databasePort The database port to use, leave empty to default by database type
	 * @databaseUsername The database username to use for the datasource
	 * @databasePassword The database password to use for the datasource
	 * @databaseName The database name to use for the datasource
	 **/
	function run(
		required name,
		cfmlEngine = "lucee@5",
		cfmlPassword = "contentbox",
		coldboxPassword = "contentbox",
		required databaseType,
		databaseHost = "localhost",
		databasePort="",
		required databaseUsername,
		required databasePassword,
		databaseName = "contentbox"
	){
		var installDir = getCWD();

		// Verify Engines
		if( !arrayFindNoCase( static.engines, arguments.cfmlEngine ) ){
			error( "The cfml engine passed (#arguments.cfmlengine#) is not valid. Valid choices are #static.engines.toString()#" );
			return;
		}

		// Verify Databases
		if( !arrayFindNoCase( static.databases, arguments.databaseType ) ){
			error( "The database passed (#arguments.databaseType#) is not valid. Valid choices are #static.databases.toString()#" );
			return;
		}

		// Install the installer
		print.blueLine( "Starting to install ContentBox..." ).line().toConsole();
		command( "install contentbox-installer@5.0.0-rc-snapshot" )
			.run();

		// Remove the dsn creator
		directoryDelete( installDir & "/modules/contentbox-dsncreator", true );

		// Seed the right CFML Engine
		print.blueLine( "Starting to seed the chosen CFML Engine..." ).line().toConsole();
		command( "server set app.cfengine=#arguments.cfmlEngine#" ).run();
		command( "server set name='#arguments.name#'" ).run();
		print.greenLine( "√ CFML Engine Configured!" ).line().toConsole();

		// Create the .env
		print.blueLine( "Starting to seed the ContentBox runtime environment..." ).line().toConsole();
		arguments.installDir = installDir;
		createEnvironment( argumentCollection = arguments );
		print.greenLine( "√ ContentBox Environment Configured!" ).line().toConsole();

		// Reload the shell
		//command( "reload" ).run();

		// Ask for startup
		print.greenLine( "ContentBox has been installed and configured. We will now verify your database credentials, install the migrations and then we can continue running the server." )
			.redBoldLine( "Make sure your database (#arguments.databaseName#) has been created!" )
			.redBoldLine( "If this process fails, then your database credentials are not correct.  Verify them and make sure they match the ones in the (.env) file we created." );

		// Confirm migrations
		waitForKey( "Press any key to continue to install the migrations?" );
		command( "migrate install" ).run();

		// Confirm starting up the server
		waitForKey( "Press any key to startup your server and you can continue with the web setup portions..." );
		command( "server start" ).run();

		print.greenLine( "√ ContentBox CLI Install Wizard is done, enjoy your ContentBox!" );
	}

	/**
	 * Create the .env file
	 */
	private function createEnvironment(
		required name,
		required cfmlEngine,
		required cfmlPassword,
		required coldboxPassword,
		required databaseType,
		required databaseHost,
		required databasePort,
		required databaseUsername,
		required databasePassword,
		required databaseName,
		required installDir
	){
		var env = fileRead( variables.settings.templatesPath & "/.env.template" );

		env = replaceNoCase( env, "APPNAME=", "APPNAME=#arguments.name#" );
		env = replaceNoCase( env, "CFCONFIG_ADMINPASSWORD=", "CFCONFIG_ADMINPASSWORD=#arguments.cfmlPassword#" );
		env = replaceNoCase( env, "COLDBOX_REINITPASSWORD=", "COLDBOX_REINITPASSWORD=#arguments.coldboxPassword#" );
		env = replaceNoCase( env, "DB_HOST=", "DB_HOST=#arguments.databaseHost#" );
		env = replaceNoCase( env, "DB_PORT=", "DB_PORT=#arguments.databasePort#" );
		env = replaceNoCase( env, "DB_DATABASE=", "DB_DATABASE=#arguments.databaseName#" );
		env = replaceNoCase( env, "DB_USER=", "DB_USER=#arguments.databaseUsername#" );
		env = replaceNoCase( env, "DB_PASSWORD=", "DB_PASSWORD=#arguments.databasePassword#" );
		env = replaceNoCase( env, "JWT_SECRET=", "JWT_SECRET=#generateSecretKey( "blowfish", 256 )#" );

		switch( arguments.databaseType ){
			case "HyperSonicSQL" : {
				env = replaceNoCase( env, "ORM_DIALECT=", "ORM_DIALECT=org.hibernate.dialect.MySQL5InnoDBDialect" );
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=MySQL" );
				env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=" );
				env = replaceNoCase( env, "DB_BUNDLENAME=", "DB_BUNDLENAME=" );
				env = replaceNoCase( env, "DB_BUNDLEVERSION=", "DB_BUNDLEVERSION=" );
				env = replaceNoCase( env, "DB_CONNECTIONSTRING=", "DB_CONNECTIONSTRING=" );
				break;
			}
			case "MySQL5" : {
				if( !len( arguments.databasePort ) ){
					arguments.databasePort = 3306;
				}
				env = replaceNoCase( env, "ORM_DIALECT=", "ORM_DIALECT=org.hibernate.dialect.MySQL5InnoDBDialect" );
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=MySQL" );
				if( findNoCase( "adobe", arguments.cfmlEngine ) ){
					env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=com.mysql.cj.jdbc.Driver" );
				} else {
					env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=com.mysql.jdbc.Driver" );
				}
				env = replaceNoCase( env, "DB_BUNDLENAME=", "DB_BUNDLENAME=com.mysql.jdbc" );
				env = replaceNoCase( env, "DB_BUNDLEVERSION=", "DB_BUNDLEVERSION=5.1.40" );
				env = replaceNoCase( env, "DB_CONNECTIONSTRING=", "DB_CONNECTIONSTRING=jdbc:mysql://#arguments.databseHost#:#arguments.databasePort#/#arguments.databaseName#?useSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC&useLegacyDatetimeCode=true" );
				break;
			}
			case "MySQL8" : {
				if( !len( arguments.databasePort ) ){
					arguments.databasePort = 3306;
				}
				env = replaceNoCase( env, "ORM_DIALECT=", "ORM_DIALECT=org.hibernate.dialect.MySQL5InnoDBDialect" );
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=MySQL" );
				env = replaceNoCase( env, "DB_BUNDLENAME=", "DB_BUNDLENAME=com.mysql.cj" );
				env = replaceNoCase( env, "DB_BUNDLEVERSION=", "DB_BUNDLEVERSION=8.0.24" );
				env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=com.mysql.cj.jdbc.Driver" );
				env = replaceNoCase( env, "DB_CONNECTIONSTRING=", "DB_CONNECTIONSTRING=jdbc:mysql://#arguments.databseHost#:#arguments.databasePort#/#arguments.databaseName#?useSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC&useLegacyDatetimeCode=true" );
				break;
			}
			case "MicrosoftSQL" : {
				if( !len( arguments.databasePort ) ){
					arguments.databasePort = 1433;
				}
				env = replaceNoCase( env, "ORM_DIALECT=", "ORM_DIALECT=org.hibernate.dialect.SQLServer2008Dialect" );
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=mssql" );
				env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=com.microsoft.sqlserver.jdbc.SQLServerDriver" );
				env = replaceNoCase( env, "DB_BUNDLENAME=", "DB_BUNDLENAME=mssqljdbc4" );
				env = replaceNoCase( env, "DB_BUNDLEVERSION=", "DB_BUNDLEVERSION=4.0.2206.100" );
				env = replaceNoCase( env, "DB_CONNECTIONSTRING=", "DB_CONNECTIONSTRING=jdbc:sqlserver://#arguments.databaseHost#:#arguments.databsePort#;DATABASENAME=#arguments.databaseName#;sendStringParametersAsUnicode=true;SelectMethod=direct" );
				break;
			}
			case "PostgreSQL" : {
				if( !len( arguments.databasePort ) ){
					arguments.databasePort = 5432;
				}
				env = replaceNoCase( env, "ORM_DIALECT=", "ORM_DIALECT=PostgreSQL" );
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=PostgreSQL" );
				env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=org.postgresql.Driver" );
				env = replaceNoCase( env, "DB_BUNDLENAME=", "DB_BUNDLENAME=org.postgresql.jdbc42" );
				env = replaceNoCase( env, "DB_BUNDLEVERSION=", "DB_BUNDLEVERSION=9.4.1212" );
				env = replaceNoCase( env, "DB_CONNECTIONSTRING=", "DB_CONNECTIONSTRING=jdbc:postgresql://#arguments.databaseHost#:#arguments.databasePort#/#arguments.databasename#" );
				break;
			}
			case "Oracle" : {
				env = replaceNoCase( env, "ORM_DIALECT=", "ORM_DIALECT=Oracle10g" );
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=oracle" );
				env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=" );
				env = replaceNoCase( env, "DB_BUNDLENAME=", "DB_BUNDLENAME=com.mysql.jdbc" );
				env = replaceNoCase( env, "DB_BUNDLEVERSION=", "DB_BUNDLEVERSION=" );
				env = replaceNoCase( env, "DB_CONNECTIONSTRING=", "DB_CONNECTIONSTRING=" );
				break;
			}
		}

		// Write it out
		fileWrite( arguments.installDir & "/.env", env, "utf-8" );
	}

	function completeEngines(){
		return static.engines;
	}

	function completeDatabases(){
		return static.databases;
	}

}