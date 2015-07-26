import 'dart:io';

import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_pg/manager.dart';

import 'package:args/args.dart';

@app.Install(urlPrefix: '/api/v1')
import 'package:targets_server/api.dart';

@app.Install(urlPrefix: '/')
import 'package:targets_server/static_routes.dart' as static_routes;

@app.Install(urlPrefix: '/')
import 'package:targets_server/login_routes.dart';

main(raw_args) {
    var args = parseArgs(raw_args);
    app.setShelfHandler(static_routes.makeHandler());
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

initDatabase(PostgreSql db) async {
    // List of registered courses
    // id: GitHub username or organization (e.g. `mvhs`)
    // name: Display name for course (e.g. `MVHS AP Java`)
    // allowed_students: JSON list of allowed student emails
    //           Emails in this list are not automatically enrolled
    //           Must use /student/:email/enroll/:course endpoint
    //           Supports @domain.com as wildcard for all emails on domain
    // enrolled_students: JSON list of enrolled studente amils
    await db.execute("""CREATE TABLE IF NOT EXISTS courses (
                    id                  text,
                    name                text,
                    allowed_students     json,
                    enrolled_students    json
                );""");
    // List of registered students
    // email: Google account email used as id
    // name: Full name automatically provided from Google account
    // courses: JSON map of enrolled courses to status
    //          Status can be "active" or "expired"
    await db.execute("""CREATE TABLE IF NOT EXISTS students (
                    email   text,
                    name    text,
                    courses json
                );""");
    // List of available assignments
    // course: Course ID this assignment is part of
    // id: Assignment ID (should match that in `tests.dart`)
    // open: Time submissions are first accepted
    // deadline: Submissions after this time are marked late
    // close: Time after which submissions are no longer accepted
    // note: optional information about assignment
    // github_url: Link to assignment template
    await db.execute("""CREATE TABLE IF NOT EXISTS assignments (
                    course      text,
                    id          text,
                    open        timestamp,
                    deadline    timestamp,
                    close       timestamp,
                    note        text,
                    github_url  text
                );""");
    // Uploaded submissions that have not yet been validated
    // These expire about 5 minutes after creation
    // course and assignment: Should match with active assignment
    // student: Student email that is making submission
    // time: time submissions is added to uploads table
    // files: JSON map of filenames to file contents
    // note: Optional note to teacher for submission
    await db.execute("""CREATE TABLE IF NOT EXISTS uploads (
                    md5         text, 
                    course      text,
                    assignment  text,
                    student     text,
                    time        timestamp DEFAULT current_timestamp,
                    files       json,
                    note        text
                );""");
    // Submissions moved here from `uploads` after being
    // validated with the student's Google account
    // Official submission time is based on the time
    // that it's moved to the submissions table, not the time
    // when it's first uploaded.
    await db.execute("""CREATE TABLE IF NOT EXISTS submissions (
                    course      text,
                    assignment  text,
                    student     text,
                    time        timestamp DEFAULT current_timestamp,
                    files       json,
                    note        text
                );""");
    
    // get rid of old uploads/submissions
    await cleanSubmissions(db);
}