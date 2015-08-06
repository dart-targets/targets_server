library api;

import 'dart:async';
import 'dart:io';

import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_pg/manager.dart';

import 'package:targets_server/models.dart';
import 'package:targets_server/login.dart' as login;

part 'auth.dart';
part 'submission.dart';

PostgreSql get db => app.request.attributes.dbConn;

/// Keeps session alive
@app.Route("/ping")
ping() {
    print("ping");
    return "pong";
}

/// Gets info about logged in user, if any
@app.Route("/user")
userInfo() {
    if (login.isStudent() || login.isTeacher()) {
        return app.request.session['profile'];
    }
}

// Student API

/// Lists all students the user has access to
@app.Route("/student")
@Encode()
studentList() async {
    return requireRead(db.query("select * from students", Student));
}

/// Provides info about a specific student (if allowed access)
@app.Route("/student/:email")
@Encode()
studentInfo(String email) async {
    return requireRead(first(db.query("select * from students where email = '$email'", Student)));
}

/// Registers a new student or updates an existing one (must be done by the student themselves)
@app.Route("/register/student", methods: const [app.POST])
addStudent(@Decode() Student student) async {
    // registration does not include any enrollment
    student.courses = [];
    await requireWrite(student);
    Student s = await studentInfo(student.email);
    if (s == null) {
        db.execute("insert into students (email, name, courses) "
                     "values (@email, @name, @courses)", student);
        return "Student '${student.email}' registered";
    } else {
        db.execute("update students set name = @name where email = @email", student);
        return "Student '${student.email}' updated";
    }
}

// Course API

/// Lists all courses the user has access to
@app.Route("/course")
@Encode()
courseList() async {
    return requireRead(db.query("select * from courses", Course));
}

/// Registers a new course or updates an existing one (must be done by an owner of the GitHub org)
@app.Route("/register/course", methods: const [app.POST])
addCourse(@Decode() Course course) async {
    await requireWrite(course);
    Course c = await courseInfo(course.id);
    if (c == null) {
        await db.execute("insert into courses (id, name, allowed_students, enrolled_students) "
                     "values (@id, @name, @allowed_students, '[]')", course);
        return "Course '${course.id}' registered";
    } else {
        await db.execute("update courses set name = @name, allowed_students = @allowed_students where id = @id", course);
        return "Course '${course.id}' updated";
    }
}

/// Provides info about a specific student (if allowed access)
@app.Route("/course/:id")
@Encode()
courseInfo(String id) async {
    return requireRead(first(db.query("select * from courses where id = '$id'", Course)));
}

/// Enrolls a given student in a given course
/// (both the course and student must be registered; done by student)
@app.Route("/course/:id/enroll/:email")
enrollStudent(String id, String email) async {
    Course course = await courseInfo(id);
    if (course == null) {
        return "No course with id '$id' exists";
    }
    Student student = await studentInfo(email);
    await requireWrite(student);
    if (student == null) {
        return "Student '$email' is not registered";
    }
    if (!course.allows(student)) {
        return "Student '$email' is not allowed to enroll in Course '$id'";
    }
    if (course.enrolledStudents.contains(email)) {
        return "Student '$email' is already enrolled in Course '$id'";
    }
    student.courses.add(id);
    course.enrolledStudents.add(email);
    db.execute("update courses set enrolled_students = @enrolled_students where id = @id", course);
    db.execute("update students set courses = @courses where email = @email", student);
    return "Student '$email' enrolled in Course '$id'";
}

// Assignment API

/// Registers a new assignment or updates an existing one
@app.Route("/register/assignment", methods: const [app.POST])
addAssignment(@Decode() Assignment assign) async {
    await requireWrite(assign);
    Assignment a = await assignmentInfo(assign.course, assign.id);
    if (a == null) {
        await db.execute("insert into assignments (course, id, open, deadline, close, note, github_url, download_code) "
                    "values (@course, @id, @open, @deadline, @close, @note, @github_url, @download_code)", assign);
        return "Assignment '${assign.id}' in  Course '${assign.course}' registered";
    } else {
        await db.execute("update assignments set open = @open, deadline = @deadline, close = @close, note = @note, github_url = @github_url "
                    "where course = @course and id = @id and download_code = @download_code", assign);
        return "Assignment '${assign.id}' in  Course '${assign.course}' updated";
    }
}

/// Provides info for a given assignment in a given course
@app.Route("/course/:course/assignment/:id")
@Encode()
assignmentInfo(String course, String id) async {
    return requireRead(first(db.query("select * from assignments where id = '$id' and course = '$course'", Assignment)));
}

/// Lists all assignments in a given course
@app.Route("/course/:course/assignment")
@Encode()
assignmentList(String course) async {
    await courseInfo(course);
    return db.query("select * from assignments where course = '$course'", Assignment);
}

/// Lists all assignments for the current student
@app.Route("/assignments")
@Encode()
allAssignments(String course) async {
    if (!login.isStudent()) {
        app.chain.interrupt(statusCode: HttpStatus.UNAUTHORIZED);
        return null;
    }
    Student me = await studentInfo(login.getGoogleEmail());
    List<Assignment> assigns = [];
    for (String course in me.courses) {
        assigns.addAll(await assignmentList(course));
    }
    return assigns;
}

/// Lists all submissions for the given assignment
@app.Route("/submissions/:course/:assign")
@Encode()
submissionsList(String course, String assign) async {
    return requireRead(db.query("select * from submissions where course = '$course' and assignment = '$assign'", Submission));
}

/// Lists all submissions from the given student
@app.Route("/student/:email/submissions")
@Encode()
studentSubmissions(String email) async {
    await studentInfo(email);
    return db.query("select * from submissions where student = '$email'", Submission);
}

first(Future dbResponse) async {
    var list = await dbResponse;
    if (list.length == 0) {
        return null;
    } else {
        return list[0];
    }
}
