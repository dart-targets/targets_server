library login;

import 'package:redstone/server.dart' as app;

bool isStudent() {
    return app.request.session['authType'] == 'google';
}

bool isTeacher() {
    return app.request.session['authType'] == 'github';
}

String getGoogleEmail() {
    return app.request.session['googleLogin'];
}

String getGithubUsername() {
    return app.request.session['githubLogin'];
}

bool isGoogle(String email) {
    return app.request.session['googleLogin'] == email;
}

bool isGithubMember(String org) {
    if (isGithubOwner(org)) {
        return true;
    }
    return false;
}

bool isGithubOwner(String org) {
    if (app.request.session['githubLogin'] == org) {
        return true;
    }
    return false;
}

// to avoid capitalization problems
var isGitHubMember = isGithubMember;
var isGitHubOwner = isGithubOwner;