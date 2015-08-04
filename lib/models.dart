library models;

import 'package:crypto/crypto.dart';

import 'package:redstone_mapper/mapper.dart';

class Student extends Object with Comparable<Student> {
    
    @Field()
    String name;
    
    @Field()
    String email;
    
    @Field()
    List<String> courses = [];
    
    @override
    int compareTo(Student other) {
        // order by last name
        String lastName = name.split(" ").last.toLowerCase();
        String otherLastName = name.split(" ").last.toLowerCase();
        int compare = lastName.compareTo(otherLastName);
        if (compare == 0) {
            return name.toLowerCase().compareTo(other.name.toLowerCase());
        } else return compare;
    }
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
    int open = 0;
    
    @Field()
    int deadline = 0;
    
    @Field()
    int close = 0;
    
    @Field()
    String note;
    
    @Field(model: 'github_url')
    String githubUrl;
    
    @Field(model: 'download_code')
    String downloadCode;
    
}

class Submission {
    
    @Field()
    String course;
    
    @Field()
    String assignment;
    
    @Field()
    String student;
    
    @Field()
    int time = 0;
    
    @Field()
    Map<String, String> files;
    
    @Field()
    String note;
    
    @override
    int compareTo(Student other) {
        // order by time (newest first)
        return other.time - time;
    }
    
}

/// Generates an MD5 hash for the given object (must be in models)
String hash(var obj) {
    if (!(obj is Student || obj is Course || 
            obj is Assignment || obj is Submission)) {
        throw new Exception("Object to hash must be in models.dart");
    }
    String json = encodeJson(obj);
    var md5 = new MD5();
    md5.add(json.codeUnits);
    var bytes = md5.close();
    return CryptoUtils.bytesToHex(bytes);
}