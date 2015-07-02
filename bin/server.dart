import 'dart:io';

import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_pg/manager.dart';
import 'package:shelf_static/shelf_static.dart';

import "package:path/path.dart" show join, dirname;
import 'package:args/args.dart';

@app.Install(urlPrefix: '/api/v1')
import 'package:targets_server/api.dart';

main(raw_args) {
    var args = parseArgs(raw_args);
    String webDir = join(dirname(dirname(Platform.script.toFilePath())), 'web');
    app.setShelfHandler(createStaticHandler(webDir, 
                        defaultDocument: "index.html", 
                        serveFilesOutsidePath: true));
    String uri = Platform.environment['POSTGRES_URI'];
    var dbManager = new PostgreSqlManager(uri);
    app.addPlugin(getMapperPlugin(dbManager));
    app.setupConsoleLog();
    app.start(port: int.parse(args['port']));
    dbManager.getConnection().then((db)=>initDatabase(db));
}

ArgResults parseArgs(args) {
    var parser = new ArgParser();
    
    parser.addOption('port', abbr:'p', defaultsTo:'8080');
    
    try {
        return parser.parse(args);
    } on FormatException {
        print("Invalid arguments.");
        exit(1);
    }
    return null;
}

initDatabase(PostgreSql db) {
    db.execute("""CREATE TABLE IF NOT EXISTS courses (
                    id text,
                    name text
                );""");
    db.execute("""CREATE TABLE IF NOT EXISTS students (
                    email text,
                    name text
                );""");
}