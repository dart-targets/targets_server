library api;

import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper/mapper.dart';
import 'package:redstone_mapper_pg/manager.dart';

part 'auth.dart';
part 'models.dart';

PostgreSql get db => app.request.attributes.dbConn;

@app.Route("/student/:email")
@Encode()
studentInfo(String email) {
    return first(db.query("select * from students where email = '$email' limit 1", Student));
}

@app.Route("/register/student", methods: const [app.POST])
addStudent(@Decode() Student student) async {
    Student s = await studentInfo(student.email);
    if (s == null) {
        return db.execute("insert into students (email, name) "
                     "values (@email, @name)", student);
    } else {
        return db.execute("update students set name = @name where email = @email", student);
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
    if (c == null) {
        return db.execute("insert into courses (id, name) "
                     "values (@id, @name)", course);
    } else {
        return db.execute("update courses set name = @name where id = @id", course);
    }
}

@app.Route("/course/:id")
@Encode()
courseInfo(String id) {
    return first(db.query("select * from courses where id = '$id' limit 1", Course));
}

Future first(Future dbResponse) {
    return dbResponse.then((resp){
        if (resp.length == 0) {
            return null;
        } else return resp[0];
    });
}
