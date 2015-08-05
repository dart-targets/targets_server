library static_routes;

import 'dart:io';
import 'package:redstone/server.dart' as app;
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' show join, dirname;
import 'package:targets_server/login.dart' as login;

String webDir = join(dirname(dirname(Platform.script.toFilePath())), 'web');

makeHandler() => createStaticHandler(webDir, defaultDocument: 'index.html', serveFilesOutsidePath: true);

@app.Interceptor(r'/console.*')
consoleBlocker() {
    String url = app.request.url.toString();
    if (url == '/console' || url == '/console/student.html' ||
            url == '/console/teacher.html' || url == '/console/unauth.html') {
        app.redirect('/console/');
    } else app.chain.next();
}

@app.Route('/console/')
consolePage() {
    if (login.isStudent()) {
        return new File(join(webDir, 'console', 'student.html'));
    } else if (login.isTeacher()) {
        return new File(join(webDir, 'console', 'teacher.html'));
    }
    return new File(join(webDir, 'console', 'unauth.html'));
}
