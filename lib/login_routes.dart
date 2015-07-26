library login_routes;

import 'dart:io';

import 'package:redstone/server.dart' as app;
import 'package:targets_server/login.dart' as login;

@app.Route('/login/google', methods: const [app.POST])
googleLogin(@app.Body(app.FORM) Map form) {
    var token = form['id_token'];
    // TODO validate profile info based on token
    app.request.session['profile'] = {
        'name': form['name'],
        'email': form['email'],
        'image': form['image'],
        'type': 'google'
    };
    app.request.session['authType'] = 'google';
    app.redirect('/console/');
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