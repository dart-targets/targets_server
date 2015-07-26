library login;

import 'package:redstone/server.dart' as app;

bool isStudent() {
    return app.request.session['authType'] == 'google';
}

bool isTeacher() {
    return app.request.session['authType'] == 'github';
}

String getGoogleEmail() {
    if (isStudent()) {
        return app.request.session['profile']['email'];
    }
    return null;
}

String getGithubUsername() {
    if (isTeacher()) {
        return app.request.session['profile']['username'];
    }
    return null;
}

bool isGoogle(String email) {
    return isStudent() && app.request.session['profile']['email'] == email;
}

bool isGithubMember(String org) {
    if (isGithubOwner(org)) {
        return true;
    }
    return false;
}

bool isGithubOwner(String org) {
    if (!isTeacher()) return false;
    if (app.request.session['profile']['username'] == org) {
        return true;
    }
    return false;
}

// to avoid capitalization problems
var isGitHubMember = isGithubMember;
var isGitHubOwner = isGithubOwner;