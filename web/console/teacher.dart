import 'dart:html';
import 'dart:async';

import 'package:targets_server/client_api.dart' as api;
import 'package:targets_server/models.dart';
import 'package:targets_server/websocket.dart';
import 'package:targets_server/editor.dart' as editor;

import 'package:redstone_mapper/mapper_factory.dart';
import 'package:bootjack/bootjack.dart';
import 'package:intl/intl.dart';

var userInfo;

String currentPage;

List<String> pages = ['assignments', 'students', 'editor'];

Course currentCourse;

List<Course> courses = [];
List<String> courseIds = [];

main() {
    bootstrapMapper();
    Dropdown.use();
    Modal.use();
    Transition.use();
    loadUserInfo().then((e)=>initUI());
}

loadUserInfo() async {
    userInfo = await api.userInfo();
    (querySelector('.user-image') as ImageElement).src = userInfo['image'];
    querySelector('.user-name').innerHtml = userInfo['name'];
    var courseList = querySelector('.course-list');
    courseList.innerHtml = "";
    var courses = [userInfo['username']];
    for (var org in userInfo['orgs']) courses.add(org);
    for (var course in courses) {
        var item = new Element.li();
        var link = new Element.a();
        link.innerHtml = course;
        item.append(link);
        item.onClick.listen((e)=>switchCourse(course));
        courseList.append(item);
    }
    return null;
}

initUI() async {
    switchPage('assignments');
    connectToClient();
    for (var page in pages) {
        querySelector('.tab-$page').onClick.listen((e)=>switchPage(page));
    }
    await findCourses();
    loadAssignments();
}

connectToClient() {
    var socketInfo = querySelector('.socket-info');
    bool isUpdating = false;
    socketConnected = () {
        loadEditor();
        socketInfo.innerHtml = "Client Connected";
        querySelector('.tab-editor').style.display = 'block';
    };
    socketDisconnected = () {
        socketInfo.innerHtml = "Client Disconnected";
        if (isUpdating) {
            socketInfo.innerHtml = "Reconnecting...";
            new Future.delayed(const Duration(seconds: 1), connectToClient);
        }
        querySelector('.tab-editor').style.display = 'none';
        if (currentPage == "editor") {
            switchPage('assignments');
        }
    };
    socketInfo.innerHtml = "Loading...";
    querySelector('.socket-reconnect').onClick.listen((e)=>connectToClient());
    querySelector('.socket-update').onClick.listen((e){
        isUpdating = true;
        socketInfo.innerHtml = "Updating...";
        requestUpdate();
    });
    connectBackground();
}

loadEditor() {
    var element = querySelector("#editor");
    element.innerHtml = "";
    editor.loadEditor(element, whenDone: loadEditor);
}

findCourses() async {
    courses = await api.getCourses();
    courseIds = [];
    for (var course in courses) courseIds.add(course.id);
    if (courses.length == 0) {
        // register a course  
    } else {
        switchCourse(courses[0].id);
    }
}

isCourseAdmin(String course) {
    return course == userInfo['username'] || userInfo['ownedOrgs'].contains(course);
}

switchCourse(String courseId) async {
    if (!courseIds.contains(courseId)) {
        // register a course
        return;
    }
    for (var course in courses) {
        if (course.id == courseId) currentCourse = course;
    }
    querySelector('.course-current').innerHtml = currentCourse.id;
    if (isCourseAdmin(courseId)) {
        querySelector('.console-title').innerHtml = "Teacher Console";
    } else {
        querySelector('.console-title').innerHtml = "Grader Console";
    }
}

loadAssignments() async {
    var assignments = await api.getAssignments(currentCourse.id);
    var container = querySelector('.assignments');
    container.innerHtml = "";
    var now = new DateTime.now().millisecondsSinceEpoch;
    for (var assign in assignments) {
        var item = new DivElement();
        item.classes = ['assignment', 'panel', 'col-xs-12', 'col-sm-12', 'col-md-6', 'col-lg-4'];
        if (now < assign.open) {
            item.classes.add('panel-warning');
        } else if (now < assign.close) {
            item.classes.add('panel-info');
        } else {
            item.classes.add('panel-success');
        }
        var heading = new DivElement()..classes = ['panel-heading'];
        var title = new HeadingElement.h3()..classes = ['panel-title'];
        title.innerHtml = assign.id;
        heading.append(title);
        var dateformat = new DateFormat('EEE, MMM d, y h:mm a');
        String open = dateformat.format(new DateTime.fromMillisecondsSinceEpoch(assign.open));
        String deadline = dateformat.format(new DateTime.fromMillisecondsSinceEpoch(assign.deadline));
        String close = dateformat.format(new DateTime.fromMillisecondsSinceEpoch(assign.close));
        var body = new DivElement()..classes = ['panel-body', 'assignment-body'];
        body.append(new DivElement()..innerHtml="<b>Open:</b>&nbsp;$open");
        body.append(new DivElement()..innerHtml="<b>Deadline:</b>&nbsp;$deadline");
        body.append(new DivElement()..innerHtml="<b>Close:</b>&nbsp;$close");
        var template = new DivElement()..innerHtml="<b>Template:</b>&nbsp;";
        template.append(new Element.a()..target='_blank'..href=assign.githubUrl..innerHtml=assign.downloadCode);
        body.append(template);
        body.append(new DivElement()..innerHtml=assign.note);
        item.append(heading);
        item.append(body);
        var footer = new DivElement()..classes = ['panel-footer'];
        footer.style.position = 'relative';
        var edit = new ButtonElement()..classes = ['btn', 'panel-btn']..innerHtml = 'Edit Assignment';
        var view = new ButtonElement()..classes = ['btn', 'panel-btn']..innerHtml = 'View Submissions';
        footer.append(edit);
        footer.append(view);
        item.append(footer);
        container.append(item);
    }
}

loadStudents() async {
    var allStudents = await api.getStudents();
    var students = [];
    var unenrolled = [];
    for (var s in allStudents) {
        if (s.courses.contains(currentCourse.id)) {
            students.add(s);
        } else if (currentCourse.allowedStudents.contains(s.email)) {
            unenrolled.add(s);
        }
    }
    students.sort();
    var enrolledList = querySelector('.enrolled-students');
    enrolledList.innerHtml = "";
    for (var s in students) {
        var item = new Element.a();
        item.classes.add('list-group-item');
        item.innerHtml = "${s.name} (${s.email})";
        enrolledList.append(item);
    }
    var unenrolledList = querySelector('.unenrolled-students');
    unenrolledList.innerHtml = "";
    for (var s in unenrolled) {
        var item = new Element.a();
        item.classes.add('list-group-item');
        item.innerHtml = "${s.name} (${s.email})";
        unenrolledList.append(item);
    }
    currentCourse.allowedStudents.sort();
    for (var s in currentCourse.allowedStudents) {
        if (!s.startsWith('@') && !currentCourse.enrolledStudents.contains(s)) {
            var item = new Element.a();
            item.classes.add('list-group-item');
            item.innerHtml = s;
            unenrolledList.append(item);
        }
    }
    var allowedDomains = querySelector('.allowed-domains');
    allowedDomains.innerHtml = "";
    for (var s in currentCourse.allowedStudents) {
        if (s.startsWith('@')) {
            var item = new Element.a();
            item.classes.add('list-group-item');
            item.innerHtml = s;
            allowedDomains.append(item);
        }
    }
}

switchPage(String page) {
    if (page == 'students') loadStudents();
    currentPage = page;
    querySelectorAll('.page').style.display = 'none';
    querySelector('.page-$page').style.display = 'block';
    querySelectorAll('.tab').classes.remove('active');
    querySelector('.tab-$page').classes.add('active');
}


