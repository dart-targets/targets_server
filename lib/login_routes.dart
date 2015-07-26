library login_routes;

import 'dart:io';
import 'dart:convert';

import 'package:redstone/server.dart' as app;
import 'package:targets_server/login.dart' as login;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

@app.Route('/login/google', methods: const [app.POST])
googleLogin(@app.Body(app.FORM) Map form) async {
    var token = form['id_token'];
    var response = await http.get('https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=$token');
    var auth = JSON.decode(response.body);
    String clientID = "563738534627-jmcuf5en3b51a6oe7k40ruid2i58hp1l.apps.googleusercontent.com";
    if (auth['email'] != form['email'] || form['aud'] != clientID || !form['email_verified']) {
        app.request.session.destroy();
        app.redirect('/console/');
    }
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
githubLogin(@app.QueryParam("code") String code, @app.QueryParam("state") String state) async {
    String id = Platform.environment['GITHUB_CLIENT_ID'];
    String secret = Platform.environment['GITHUB_CLIENT_SECRET'];
    if (state != app.request.session['github_auth_state']) {
        app.request.session.destroy();
        app.redirect('/console/');
    }
    String url = "https://github.com/login/oauth/access_token";
    var body = {
        'client_id': Platform.environment['GITHUB_CLIENT_ID'],
        'client_secret': Platform.environment['GITHUB_CLIENT_SECRET'],
        'code': code,
        'state': state
    };
    var headers = {'Accept': 'application/json'};
    var response = await http.post(url, body: body, headers: headers);
    var token = JSON.decode(response.body)['access_token'];
    headers['Authorization'] = 'token $token';
    var userResp = await http.get('https://api.github.com/user', headers: headers);
    var user = JSON.decode(userResp.body);
    var profile = {
        'name': user['name'],
        'username': user['login'],
        'email': user['email'],
        'image': user['avatar_url'],
        'orgs': [],
        'ownedOrgs': [],
        'type': 'github'
    };
    var orgsResp = await http.get('https://api.github.com/user/orgs', headers: headers);
    var orgs = JSON.decode(orgsResp.body);
    for (var org in orgs) {
        String orgName = org['login'];
        profile['orgs'].add(orgName);
        var resp = await http.get('https://api.github.com/orgs/$orgName/members?role=admin', headers: headers);
        var admins = JSON.decode(resp.body);
        for (var admin in admins) {
            if (admin['login'] == profile['username']) {
                profile['ownedOrgs'].add(orgName);
                break;
            }
        }
    }
    app.request.session['profile'] = profile;
    app.request.session['authType'] = 'github';
    app.redirect('/console/');
}

@app.Route('/authflow/github')
githubAuthFlow() {
    String base = "https://github.com/login/oauth/authorize";
    String id = Platform.environment['GITHUB_CLIENT_ID'];;
    String fullUrl = app.request.requestedUri.toString();
    String route = app.request.url.toString();
    String domain = fullUrl.substring(0, fullUrl.length - route.length);
    String redirect = domain + "/login/github";
    String scope = "read:org";
    String state = new Uuid().v4();
    app.request.session['github_auth_state'] = state;
    String url = "$base?client_id=$id&redirect_uri=$redirect&scope=$scope&state=$state";
    app.redirect(url);
}

@app.Route('/logout')
logout() {
    app.request.session.destroy();
    app.redirect('/console/');
}
