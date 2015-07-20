part of api;

@app.Interceptor(r'/.*')
authFilter() {
    // eventually, we need to handle proper login with GitHub and Google
    // for right now, we'll look for a "github" header or a "google" header
    // with the user/org name or email address as the value.
    var session = app.request.session;
    if (app.request.headers.containsKey('github')) {
        session['githubLogin'] = app.request.headers.github;
        session['githubOrgs'] = [app.request.headers.github];
        session['githubOwnedOrgs'] = [app.request.headers.github];
    } else {
        session['githubLogin'] = null;
        session['githubOrgs'] = [];
        session['githubOwnedOrgs'] = [];
    }
    if (app.request.headers.containsKey('google')) {
        session['googleLogin'] = app.request.headers.google;
    } else session['googleLogin'] = null;
    app.chain.next(() => app.request.session.destroy());
}

int NO_ACCESS = 0;
int READ_ACCESS = 1;
int WRITE_ACCESS = 2;
// for data not one of the protected models
int UNRESTRICTED = 3;

requireRead(var data) async {
    if (data is Future) {
        data = await data;
    }
    if (data is List) {
        var filtered = [];
        for (var subdata in data) {
            if (await accessLevel(subdata) >= READ_ACCESS) {
                filtered.add(subdata);
            }
        }
        return filtered;
    }
    if (await accessLevel(data) < READ_ACCESS) {
        app.chain.interrupt(statusCode: HttpStatus.UNAUTHORIZED);
    }
    return data;
}

requireWrite(var data) async {
    if (data is Future) {
        data = await data;
    }
    if (data is List) {
        filtered = [];
        for (var subdata in data) {
            if (await accessLevel(subdata) >= WRITE_ACCESS) {
                filtered.add(subdata);
            }
        }
        return filtered;
    }
    if (await accessLevel(data) < WRITE_ACCESS) {
        app.chain.interrupt(statusCode: HttpStatus.UNAUTHORIZED);
    }
    return data;
}

/// data can be a Course, Student, Assignment, or Submission
accessLevel(var data) async {
    var session = app.request.session;
    if (data is Course) {
        return courseAccess(data);
    } else if (data is Student) {
        if (data.email == null) return NO_ACCESS;
        if (data.email == session['googleLogin']) {
            return WRITE_ACCESS;
        }
        for (String course in data.courses) {
            if (session['githubOrgs'].contains(course)) {
                return READ_ACCESS;
            }
        }
        return NO_ACCESS;
    } else if (data is Assignment) {
        Course course = await courseInfo(data.course);
        if (course == null) {
            return NO_ACCESS;
        }
        return courseAccess(course);
    } else if (data is Submission) {
        Student student = await studentInfo(data.student);
        Course course = await courseInfo(data.course);
        Assignment assignment = await assignmentInfo(data.course, data.assignment);
        if (student == null || course == null || assignment == null) {
            return NO_ACCESS;
        }
        if (student.email = session['googleLogin'] && 
                student.courses.contains(data.course)) {
            return WRITE_ACCESS;
        }
        if (course.id == null) return NO_ACCESS;
        if (session['githubOrgs'].contains(course.id)) {
            return READ_ACCESS;
        }
    }
    return UNRESTRICTED;
}

courseAccess(Course course) {
    var session = app.request.session;
    if (course.id == null) return NO_ACCESS;
    if (course.id == session['githubLogin'] || session['githubOwnedOrgs'].contains(course.id)) {
        return WRITE_ACCESS;
    } else if (session['githubOrgs'].contains(course.id)) {
        return READ_ACCESS;
    } else if (session['googleLogin'] == null) {
        return NO_ACCESS;
    }
    Student student = new Student()..email = session['googleLogin'];
    if (course.allows(student)) {
        return READ_ACCESS;
    }
    return NO_ACCESS;
}