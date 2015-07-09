library api;

import 'dart:async';
import 'dart:io';

import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper/mapper.dart';
import 'package:redstone_mapper_pg/manager.dart';

import 'package:targets_server/models.dart';

part 'auth.dart';

PostgreSql get db => app.request.attributes.dbConn;

@app.Route("/student")
@Encode()
studentList() async {
    return requireRead(db.query("select * from students", Student));
}

@app.Route("/student/:email")
@Encode()
studentInfo(String email) async {
    return requireRead(first(db.query("select * from students where email = '$email'", Student)));
}

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

@app.Route("/course")
@Encode()
courseList() async {
    return requireRead(db.query("select * from courses", Course));
}

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

@app.Route("/course/:id")
@Encode()
courseInfo(String id) async {
    return requireRead(first(db.query("select * from courses where id = '$id'", Course)));
}

@app.Route("/course/:course/assignment/:id")
@Encode()
assignmentInfo(String course, String id) async {
    return requireRead(first(db.query("select * from assignments where id = '$id' and course = '$course'", Assignment)));
}

@app.Route("/course/:course/assignment")
@Encode()
assignmentList(String course) async {
    await courseInfo(course);
    return db.query("select * from assignments where course = '$course'", Assignment);
}

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

first(Future dbResponse) async {
    var list = await dbResponse;
    if (list.length == 0) {
        return null;
    } else {
        return list[0];
    }
}
