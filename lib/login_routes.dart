library login_routes;

import 'dart:io';

import 'package:redstone/server.dart' as app;
import 'package:targets_server/login.dart' as login;

@app.Interceptor(r'/.*')
authFilter() {
    // eventually, we need to handle proper login with GitHub and Google
    // for right now, we'll look for a "github" header or a "google" header
    // with the user/org name or email address as the value.
    var session = app.request.session;
    if (app.request.headers.containsKey('github')) {
        session['githubLogin'] = app.request.headers.github;
        session['googleLogin'] = null;
        session['authType'] = 'github';
    } else if (app.request.headers.containsKey('google')) {
        session['googleLogin'] = app.request.headers.google;
        session['githubLogin'] = null;
        session['authType'] = 'google';
    } else {
        session['googleLogin'] = null;
        session['githubLogin'] = null;
        session['authType'] = 'none';
    }
    app.chain.next(() => app.request.session.destroy());
}

@app.Route('/login/google')
googleLogin() {
    // TODO: Listen for Google OAuth callback
    app.redirect('/console/')
}

@app.Route('/login/github')
githubLogin() {
    // TODO: Listen for GitHub OAuth callback
    app.redirect('/console/');
}

@app.Route('/logout')
logout() {
    app.request.session.destroy();
    app.redirect('/console/');
}