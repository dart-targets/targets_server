library client_api;

import 'dart:html';
import 'dart:convert';
import 'dart:async';

import 'package:redstone_mapper/mapper.dart' as mapper;

import 'package:targets_server/models.dart';

/// Provides an interface for the client to make API requests to the server.

String apiRoot = '/api/v1';

Future<String> get(String path) async {
    if (!path.startsWith('/')) {
        path = '/$path';
    }
    String url = apiRoot + path;
    var response = await HttpRequest.request(url);
    if (response.status >= 300) return null;
    return response.responseText;
}

Future<String> post(String path, String data) async {
    if (!path.startsWith('/')) {
        path = '/$path';
    }
    String url = apiRoot + path;
    var headers = {
        'Content-Type': 'application/json'
    };
    var response = await HttpRequest.request(url, method: 'POST', 
                    mimeType:'application/json', requestHeaders: headers, sendData: data);
    if (response.status >= 300) return null;
    return response.responseText;
}

Future<Map> userInfo() async {
    String resp = await get('/user');
    return resp == null ? resp : JSON.decode(resp);
}

Future<List<Student>> getStudents() async {
    String resp = await get('/student');
    if (resp == null) return null;
    var decoded = JSON.decode(resp);
    return mapper.decode(decoded, Student);
}

Future<Student> getStudent(String email) async {
    String resp = await get('/student/$email');
    return resp == null ? resp : mapper.decodeJson(resp, Student);
}

Future<String> registerStudent(Student student) async {
    String data = mapper.encodeJson(student);
    return post('/register/student', data);
}

Future<List<Course>> getCourses() async {
    String resp = await get('/course');
    if (resp == null) return null;
    var decoded = JSON.decode(resp);
    return mapper.decode(decoded, Course);
}

Future<Course> getCourse(String id) async {
    String resp = await get('/course/$id');
    return resp == null ? resp : mapper.decodeJson(resp, Course);
}

Future<String> registerCourse(Course course) async {
    String data = mapper.encodeJson(course);
    return post('/register/course', data);
}

enrollStudent(String course, String student) => get('/course/$course/enroll/$student');

Future<String> registerAssignment(Assignment assign) async {
    String data = mapper.encodeJson(assign);
    return post('/register/assignment', data);
}

Future<List<Assignment>> getAssignments(String course) async {
    String resp = await get('/course/$course/assignment');
    if (resp == null) return null;
    var decoded = JSON.decode(resp);
    return mapper.decode(decoded, Assignment);
}

Future<Assignment> getAssignment(String course, String id) async {
    String resp = await get('/course/$course/assignment/$id');
    return resp == null ? resp : mapper.decodeJson(resp, Assignment);
}

Future<List<Submission>> getSubmissions(String course, String assign) async {
    String resp = await get('/submissions/$course/$assign');
    if (resp == null) return null;
    var decoded = JSON.decode(resp);
    return mapper.decode(decoded, Submission);
}
