# targets_server #

This project is eventually designed to replace the existing PHP scripts used for submission by the [Targets][client_github] assignment manager. The server is written in Dart and uses the [Redstone][redstone] framework and a PostgreSQL database.

The current version of the Targets client is not compatible with this server. Once the server is more complete, we'll begin development of an updated client on a separate branch.

## Requirements ##

This server requires Dart and PostgreSQL to be installed. A `POSTGRES_URI` environment variable must be available in the form `postgres://USER:PASSWORD@localhost:PORT/DB_NAME`. The server will use the database specified in this URI for data storage. You do not need to configure any tables, as the server will create any that it needs.

## Usage Instructions ##

Use the following steps to set up and run the server. It is not even close to being complete. Right now, it supports registering students (by name and email) and courses (by name and GitHub id) and then querying those that have been registered.

1. Clone this repository and open it on your command line.
2. Run `pub get` to fetch the server's dependencies.
3. Install [grinder][grinder] with `pub global activate grinder`.
4. Run `grind all` to build the server.
5. Run `dart build/bin/server.dart` to start the server on port 8080. Use `--port` to change this.

If you want to rebuild the server after a change, repeat steps 4 and 5. If you don't change the pubspec or the client-side web code in the `web` directory, you can run `grind server_only` to skip the JavaScript compilation.

[client_github]: https://github.com/dart-targets/targets
[redstone]: http://redstonedart.org
[grinder]: https://pub.dartlang.org/package/grinder