/**
 * A CLI based ContentBox installer. This is an automated approach to installing ContentBox.
 *
 * This command is meant to be ran and not expecting user feedback.
 *
 * The supported CFML Engines are "lucee@5", "adobe@2016", "adobe@2018", "adobe@2021"
 * The supported Databases are: "HyperSonicSQL (Lucee Only)", "MySQL5", "MySQL8", "MicrosoftSQL", "PostgreSQL", "Oracle"
 *
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
		engines = [
			"lucee@5",
			"adobe@2016",
			"adobe@2018",
			"adobe@2021"
		];
		databases = [
			"HyperSonicSQL",
			"MySQL5",
			"MySQL8",
			"MicrosoftSQL",
			"PostgreSQL",
			"Oracle"
		];
		hypersonicSlug    = "6DD4728A-AB0C-4F67-9DCE1A91A8ACD114";
		contentboxVersion = "5";
	};

	/**
	 * Install ContentBox on the current working directory with or without a running CFML Engine
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
	 * @databaseUsername The database username to use for the datasource. Use sa if using Hypersonic
	 * @databasePassword The database password to use for the datasource. Use an empty password if using Hypersonic
	 * @databaseName The database name to use for the datasource
	 * @production Are we installing for development or production, default is for development
	 * @deployServer If true, we will deploy and start the binded server via CommandBox
	 * @verbose Output much more verbose information about the installation process
	 **/
	function run(
		required name,
		cfmlEngine      = "lucee@5",
		cfmlPassword    = "contentbox",
		coldboxPassword = "contentbox",
		required databaseType,
		databaseHost = "localhost",
		databasePort = "",
		required databaseUsername,
		required databasePassword,
		databaseName         = "contentbox",
		boolean production   = false,
		boolean deployServer = true,
		boolean verbose      = false,
		contentboxVersion    = static.contentboxVersion
	){
		var installDir = getCWD();

		// Verify Engines
		if ( !arrayFindNoCase( static.engines, arguments.cfmlEngine ) ) {
			error(
				"The CFML engine passed (#arguments.cfmlengine#) is not valid. Valid choices are #static.engines.toString()#"
			);
			return;
		}

		// Verify Databases
		if (
			!arrayFindNoCase(
				static.databases,
				arguments.databaseType
			)
		) {
			error(
				"The database passed (#arguments.databaseType#) is not valid. Valid choices are #static.databases.toString()#"
			);
			return;
		}

		// Install the installer
		variables.print
			.blueLine( "Starting to install ContentBox..." )
			.line()
			.toConsole();

		command( "install" )
			.params(
				id         = "contentbox-installer@#arguments.contentboxVersion#",
				production = arguments.production,
				verbose    = arguments.verbose
			)
			.run();

		// MySQL 8 Bug on Lucee
		if ( arguments.cfmlEngine.findNoCase( "lucee" ) && arguments.databaseType == "MySQL8" ) {
			variables.print
				.blueLine( "Lucee and MySQL 8 detected, updating Application.cfc due to Lucee ORM DDL Bug..." )
				.line()
				.toConsole();
			var appCFC = replaceNoCase(
				fileRead(
					installDir & "/Application.cfc",
					"utf-8"
				),
				"""update""",
				"""dropcreate"""
			);
			fileWrite(
				installDir & "/Application.cfc",
				appCFC,
				"utf-8"
			);
			variables.print
				.greenLine( "√ Updated Application.cfc with dropcreate for MySQL 8 for initial startup." )
				.line()
				.toConsole();
		}

		// Seed the right CFML Engine to deploy
		if ( arguments.deployServer ) {
			variables.print
				.blueLine( "Starting to seed the chosen CFML Engine (#arguments.cfmlEngine#) to deploy..." )
				.line()
				.toConsole();

			command( "server set app.cfengine=#arguments.cfmlEngine#" ).run();
			command( "server set name='#arguments.name#'" ).run();
			command( "server set openBrowser=false" ).run();

			variables.print
				.greenLine( "√ CFML Engine Configured!" )
				.line()
				.toConsole();
		}

		// Create the .env
		variables.print
			.blueLine( "Starting to seed the ContentBox runtime environment..." )
			.line()
			.toConsole();
		arguments.installDir = installDir;
		createEnvironment( argumentCollection = arguments );
		variables.print
			.greenLine( "√ ContentBox Environment Configured!" )
			.line()
			.toConsole();

		// Ask for startup
		variables.print
			.greenLine(
				"ContentBox has been installed and configured on disk. We will now verify your database credentials, and install the database migrations."
			)
			.redBoldLine( "Make sure your database (#arguments.databaseName#) has been created!" )
			.redBoldLine(
				"If this process fails, then your database credentials are not correct.  Verify them and make sure they match the ones in the (.env) file we created."
			)
			.redBoldLine(
				"You don't have to run the installer again if it fails. You can run the following commands to finish your installation:"
			)
			.redBoldLine( "- migrate install" )
			.redBoldLine( "- run-script contentbox:migrate" );

		// Confirm migrations
		variables.print
			.line()
			.blueLine( "Please wait while we install your migrations table..." )
			.toConsole();
		sleep( 1000 );
		command( "migrate install" ).run();

		// Confirm starting up the server
		if ( arguments.deployServer ) {
			variables.print
				.line()
				.blueLine( "Please wait while we startup your CommandBox server..." )
				.toConsole();
			command( "server start" ).run();
			sleep( 5000 );

			// Adobe 2021 cfpm installs
			if ( arguments.cfmlEngine.findNoCase( "adobe@2021" ) ) {
				variables.print
					.line()
					.blueLine( "* Adobe 2021 detected, running cfpm installs to support ContentBox..." )
					.toConsole();
				command( "cfpm install zip,orm,mysql,postgresql,sqlserver,document,feed" ).run();
				variables.print.greenLine( "√ CFPM modules installed" );
				sleep( 5000 );
			}

			variables.print.greenLine( "√ ContentBox server started, check out the details below:" );
			command( "server info" ).run();

			variables.print.greenLine( "√ Opening a browser for you to continue with the web installer..." );
			command( "server open" ).run();
		} else {
			variables.print
				.line()
				.boldRedLine(
					"* You did not deploy a server, so you must manually start your (#arguments.cfmlengine#) engine and visit the site so you can continue the web installer portions."
				)
				.line();
		}

		variables.print.greenLine( "√ ContentBox installation is done, enjoy your ContentBox!" );
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
		required installDir,
		required production
	){
		var env = fileRead( variables.settings.templatesPath & "/.env.template" );

		env = replaceNoCase(
			env,
			"APPNAME=",
			"APPNAME=#arguments.name#"
		);
		if ( arguments.production ) {
			env = replaceNoCase(
				env,
				"ENVIRONMENT=development",
				"ENVIRONMENT=production"
			);
		}
		env = replaceNoCase(
			env,
			"CFCONFIG_ADMINPASSWORD=",
			"CFCONFIG_ADMINPASSWORD=#arguments.cfmlPassword#"
		);
		env = replaceNoCase(
			env,
			"COLDBOX_REINITPASSWORD=",
			"COLDBOX_REINITPASSWORD=#arguments.coldboxPassword#"
		);
		env = replaceNoCase(
			env,
			"DB_HOST=",
			"DB_HOST=#arguments.databaseHost#"
		);
		env = replaceNoCase(
			env,
			"DB_DATABASE=",
			"DB_DATABASE=#arguments.databaseName#"
		);
		env = replaceNoCase(
			env,
			"DB_USER=",
			"DB_USER=#arguments.databaseUsername#"
		);
		env = replaceNoCase(
			env,
			"DB_PASSWORD=",
			"DB_PASSWORD=#arguments.databasePassword#"
		);
		env = replaceNoCase(
			env,
			"JWT_SECRET=",
			"JWT_SECRET=#generateSecretKey( "blowfish", 256 )#"
		);

		switch ( arguments.databaseType ) {
			case "HyperSonicSQL": {
				env = replaceNoCase(
					env,
					"DB_USER=#arguments.databaseUsername#",
					"DB_USER=sa"
				);
				env = replaceNoCase(
					env,
					"DB_PASSWORD=#arguments.databasePassword#",
					"DB_PASSWORD="
				);
				env = replaceNoCase(
					env,
					"ORM_DIALECT=",
					"ORM_DIALECT=org.hibernate.dialect.MySQL5InnoDBDialect"
				);
				env = replaceNoCase(
					env,
					"DB_DRIVER=",
					"DB_DRIVER=hsqldb"
				);
				env = replaceNoCase(
					env,
					"DB_CLASS=",
					"DB_CLASS=org.hsqldb.jdbcDriver"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLENAME=",
					"DB_BUNDLENAME=org.hsqldb.hsqldb"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLEVERSION=",
					"DB_BUNDLEVERSION=2.4.0"
				);
				env = replaceNoCase(
					env,
					"DB_CONNECTIONSTRING=",
					"DB_CONNECTIONSTRING=jdbc:hsqldb:file:contentboxDB/#arguments.databasename#"
				);
				// Setup the jdbc extension
				command( "server set jvm.args='-Dlucee-extensions=6DD4728A-AB0C-4F67-9DCE1A91A8ACD114'" );
				break;
			}
			case "MySQL5": {
				if ( !len( arguments.databasePort ) ) {
					arguments.databasePort = 3306;
				}
				env = replaceNoCase(
					env,
					"ORM_DIALECT=",
					"ORM_DIALECT=org.hibernate.dialect.MySQL5InnoDBDialect"
				);
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=MySQL" );
				env = replaceNoCase(
					env,
					"DB_PORT=",
					"DB_PORT=#arguments.databasePort#"
				);
				env = replaceNoCase(
					env,
					"DB_CLASS=",
					"DB_CLASS=com.mysql.jdbc.Driver"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLENAME=",
					"DB_BUNDLENAME=com.mysql.jdbc"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLEVERSION=",
					"DB_BUNDLEVERSION=5.1.40"
				);
				env = replaceNoCase(
					env,
					"DB_CONNECTIONSTRING=",
					"DB_CONNECTIONSTRING=jdbc:mysql://#arguments.databaseHost#:#arguments.databasePort#/#arguments.databaseName#?useSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC&useLegacyDatetimeCode=true"
				);
				break;
			}
			case "MySQL8": {
				if ( !len( arguments.databasePort ) ) {
					arguments.databasePort = 3306;
				}
				env = replaceNoCase(
					env,
					"DB_PORT=",
					"DB_PORT=#arguments.databasePort#"
				);
				env = replaceNoCase(
					env,
					"ORM_DIALECT=",
					"ORM_DIALECT=org.hibernate.dialect.MySQL5InnoDBDialect"
				);
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=MySQL" );
				env = replaceNoCase(
					env,
					"DB_BUNDLENAME=",
					"DB_BUNDLENAME=com.mysql.cj"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLEVERSION=",
					"DB_BUNDLEVERSION=8.0.24"
				);
				env = replaceNoCase(
					env,
					"DB_CLASS=",
					"DB_CLASS=com.mysql.cj.jdbc.Driver"
				);
				env = replaceNoCase(
					env,
					"DB_CONNECTIONSTRING=",
					"DB_CONNECTIONSTRING=jdbc:mysql://#arguments.databaseHost#:#arguments.databasePort#/#arguments.databaseName#?allowPublicKeyRetrieval=true&useSSL=false&useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC&useLegacyDatetimeCode=true"
				);
				break;
			}
			case "MicrosoftSQL": {
				if ( !len( arguments.databasePort ) ) {
					arguments.databasePort = 1433;
				}
				env = replaceNoCase(
					env,
					"DB_PORT=",
					"DB_PORT=#arguments.databasePort#"
				);
				env = replaceNoCase(
					env,
					"ORM_DIALECT=",
					"ORM_DIALECT=org.hibernate.dialect.SQLServer2008Dialect"
				);
				env = replaceNoCase( env, "DB_DRIVER=", "DB_DRIVER=mssql" );
				env = replaceNoCase(
					env,
					"DB_CLASS=",
					"DB_CLASS=com.microsoft.sqlserver.jdbc.SQLServerDriver"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLENAME=",
					"DB_BUNDLENAME=mssqljdbc4"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLEVERSION=",
					"DB_BUNDLEVERSION=4.0.2206.100"
				);
				env = replaceNoCase(
					env,
					"DB_CONNECTIONSTRING=",
					"DB_CONNECTIONSTRING=jdbc:sqlserver://#arguments.databaseHost#:#arguments.databasePort#;DATABASENAME=#arguments.databaseName#;sendStringParametersAsUnicode=true;SelectMethod=direct"
				);
				break;
			}
			case "PostgreSQL": {
				if ( !len( arguments.databasePort ) ) {
					arguments.databasePort = 5432;
				}
				env = replaceNoCase(
					env,
					"DB_PORT=",
					"DB_PORT=#arguments.databasePort#"
				);
				env = replaceNoCase(
					env,
					"ORM_DIALECT=",
					"ORM_DIALECT=PostgreSQL"
				);
				env = replaceNoCase(
					env,
					"DB_DRIVER=",
					"DB_DRIVER=PostgreSQL"
				);
				env = replaceNoCase(
					env,
					"DB_CLASS=",
					"DB_CLASS=org.postgresql.Driver"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLENAME=",
					"DB_BUNDLENAME=org.postgresql.jdbc42"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLEVERSION=",
					"DB_BUNDLEVERSION=9.4.1212"
				);
				env = replaceNoCase(
					env,
					"DB_CONNECTIONSTRING=",
					"DB_CONNECTIONSTRING=jdbc:postgresql://#arguments.databaseHost#:#arguments.databasePort#/#arguments.databasename#"
				);
				break;
			}
			case "Oracle": {
				env = replaceNoCase(
					env,
					"ORM_DIALECT=",
					"ORM_DIALECT=Oracle10g"
				);
				env = replaceNoCase(
					env,
					"DB_DRIVER=",
					"DB_DRIVER=oracle"
				);
				env = replaceNoCase( env, "DB_CLASS=", "DB_CLASS=" );
				env = replaceNoCase(
					env,
					"DB_BUNDLENAME=",
					"DB_BUNDLENAME=com.mysql.jdbc"
				);
				env = replaceNoCase(
					env,
					"DB_BUNDLEVERSION=",
					"DB_BUNDLEVERSION="
				);
				env = replaceNoCase(
					env,
					"DB_CONNECTIONSTRING=",
					"DB_CONNECTIONSTRING="
				);
				break;
			}
		}

		// Write it out
		fileWrite(
			arguments.installDir & "/.env",
			env,
			"utf-8"
		);
	}

	function completeEngines(){
		return static.engines;
	}

	function completeDatabases(){
		return static.databases;
	}

}
