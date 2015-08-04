part of api;

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
        var filtered = [];
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
    if (data is Course) {
        return courseAccess(data);
    } else if (data is Student) {
        if (data.email == null) return NO_ACCESS;
        if (login.isGoogle(data.email)) {
            return WRITE_ACCESS;
        }
        for (String course in data.courses) {
            if (login.isGithubMember(course)) {
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
        if (login.isGoogle(student.email) && 
                student.courses.contains(data.course)) {
            return WRITE_ACCESS;
        }
        if (course.id == null) return NO_ACCESS;
        if (login.isGitHubMember(course.id)) {
            return READ_ACCESS;
        }
    }
    return UNRESTRICTED;
}

courseAccess(Course course) {
    if (course.id == null) return NO_ACCESS;
    if (login.isGithubOwner(course.id)) {
        return WRITE_ACCESS;
    } else if (login.isGitHubMember(course.id)) {
        return READ_ACCESS;
    } else if (!login.isStudent()) {
        return NO_ACCESS;
    }
    Student student = new Student()..email = login.getGoogleEmail();
    if (course.allows(student)) {
        // prevents students from reading enrolled list
        // may change later
        course.enrolledStudents = null;
        return READ_ACCESS;
    }
    return NO_ACCESS;
}