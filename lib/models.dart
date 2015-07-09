library models;

import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper/mapper.dart';
import 'package:redstone_mapper_pg/manager.dart';

class Student {
    
    @Field()
    String name;
    
    @Field()
    String email;
    
    @Field()
    List<String> courses = [];
}

class Course {
    
    @Field()
    String id;
    
    @Field()
    String name;
    
    @Field(model: 'allowed_students')
    List<String> allowedStudents = [];
    
    @Field(model: 'enrolled_students')
    List<String> enrolledStudents = [];
    
    /// Returns true if [student] is allowed in course
    /// Returns false otherwise
    bool allows(Student student) {
        for (String allowed in allowedStudents) {
            if (allowed == student.email || 
                    (allowed.startsWith("@") &&
                    student.email.endsWith(allowed))) {
                return true;
            } 
        }
        return false;
    }
}

class Assignment {
    
    @Field()
    String course;
    
    @Field()
    String id;
    
    @Field()
    DateTime open;
    
    @Field()
    DateTime deadline;
    
    @Field()
    DateTime close;
    
    @Field()
    String note;
    
    @Field(model: 'github_url')
    String githubUrl;
    
}

class Submission {
    
    @Field()
    String course;
    
    @Field()
    String assignment;
    
    @Field()
    String student;
    
    @Field()
    DateTime time;
    
    @Field()
    Map<String, String> files;
    
    @Field()
    String note;
    
}