library api;

import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper/mapper.dart';
import 'package:redstone_mapper_pg/manager.dart';

import 'package:targets_server/models.dart';

part 'auth.dart';

PostgreSql get db => app.request.attributes.dbConn;

@app.Route("/student/:email")
@Encode()
studentInfo(String email) {
    return first(db.query("select * from students where email = '$email' limit 1", Student));
}

@app.Route("/register/student", methods: const [app.POST])
addStudent(@Decode() Student student) async {
    // registration does not include any enrollment
    student.courses = [];
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
courseList() {
    return db.query("select * from courses", Course);
}

@app.Route("/register/course", methods: const [app.POST])
addCourse(@Decode() Course course) async {
    Course c = await courseInfo(course.id);
    print(course.name);
    print(course.id);
    print(course.allowedStudents);
    print(course.enrolledStudents);
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
courseInfo(String id) {
    return first(db.query("select * from courses where id = '$id' limit 1", Course));
}

@app.Route("/course/:id/enroll/:email")
enrollStudent(String id, String email) async {
    Course course = await courseInfo(id);
    if (course == null) {
        return "No course with id '$id' exists";
    }
    Student student = await studentInfo(email);
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

Future first(Future dbResponse) {
    return dbResponse.then((resp){
        if (resp.length == 0) {
            return null;
        } else return resp[0];
    });
}
