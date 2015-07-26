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
    if (!isTeacher()) return false;
    var profile = app.request.session['profile'];
    return profile['username'] == org || profile['orgs'].contains(org);
}

bool isGithubOwner(String org) {
    if (!isTeacher()) return false;
    var profile = app.request.session['profile'];
    return profile['username'] == org || profile['ownedOrgs'].contains(org);
}

// to avoid capitalization problems
var isGitHubMember = isGithubMember;
var isGitHubOwner = isGithubOwner;