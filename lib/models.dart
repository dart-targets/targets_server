part of api;

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