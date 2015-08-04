import 'dart:html';
import 'dart:async';
import 'dart:js';
import 'dart:convert';

import 'package:targets_server/client_api.dart' as api;
import 'package:targets_server/models.dart';
import 'package:targets_server/websocket.dart';
import 'package:targets_server/editor.dart' as editor;

import 'package:redstone_mapper/mapper_factory.dart';
import 'package:bootjack/bootjack.dart';
import 'package:intl/intl.dart';

var userInfo;

String currentPage;

List<String> pages = ['submissions', 'assignments', 'students', 'editor'];

Course currentCourse;

List<Course> courses = [];
List<String> courseIds = [];

Map<String, Student> students = {};

List<Student> studentList = [];

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
}

connectToClient() {
    var socketInfo = querySelector('.socket-info');
    bool isUpdating = false;
    onSocketConnected = () {
        loadEditor();
        socketInfo.innerHtml = "Client Connected";
        querySelectorAll('.requires-socket').style.display = 'block';
        querySelectorAll('.socket-btn').classes.remove('disabled');
    };
    onSocketDisconnected = () {
        socketInfo.innerHtml = "Client Disconnected";
        if (isUpdating) {
            socketInfo.innerHtml = "Reconnecting...";
            new Future.delayed(const Duration(seconds: 1), connectToClient);
        }
        querySelectorAll('.requires-socket').style.display = 'none';
        querySelectorAll('.socket-btn').classes.add('disabled');
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
    loadAssignments();
    loadStudents();
}

loadAssignments() async {
    var assignments = await api.getAssignments(currentCourse.id);
    var container = querySelector('.assignments');
    container.innerHtml = "";
    for (var assign in assignments) {
        container.append(makeAssignment(assign));
    }
}

Element makeAssignment(Assignment assign) {
    var now = new DateTime.now().millisecondsSinceEpoch;
    var item = new DivElement();
    item.classes = ['assignment', 'panel', 'col-xs-12', 'col-sm-6', 'col-md-6', 'col-lg-4'];
    if (now < assign.open) {
        item.classes.add('panel-warning');
    } else if (now < assign.deadline) {
        item.classes.add('panel-info');
    } else {
        item.classes.add('panel-success');
    }
    var heading = new DivElement()..classes = ['panel-heading'];
    var title = new HeadingElement.h3()..classes = ['panel-title'];
    title.innerHtml = assign.id;
    heading.append(title);
    String open = formatTime(assign.open);
    String deadline = formatTime(assign.deadline);
    String close = formatTime(assign.close);
    var body = new DivElement()..classes = ['panel-body', 'assignment-body'];
    body.append(new DivElement()..innerHtml="<b>Open:</b>&nbsp;$open");
    body.append(new DivElement()..innerHtml="<b>Deadline:</b>&nbsp;$deadline");
    body.append(new DivElement()..innerHtml="<b>Close:</b>&nbsp;$close");
    var template = new DivElement()..innerHtml="<b>Template:</b>&nbsp;";
    template.append(new Element.a()..target='_blank'..href=assign.githubUrl..innerHtml=assign.downloadCode);
    body.append(template);
    body.append(new DivElement()..innerHtml="<b>Note:</b>&nbsp;${assign.note}");
    item.append(heading);
    item.append(body);
    var footer = new DivElement()..classes = ['panel-footer'];
    footer.style.position = 'relative';
    var edit = new ButtonElement()..classes = ['btn', 'panel-btn']..innerHtml = 'Edit Assignment';
    var view = new ButtonElement()..classes = ['btn', 'panel-btn']..innerHtml = 'View Submissions';
    view.onClick.listen((e) => loadSubmissions(assign));
    footer.append(edit);
    footer.append(view);
    item.append(footer);
    return item;
}

String formatTime(int millis) {
    var dateformat = new DateFormat('EEE, MMM d, y h:mm a');
    return dateformat.format(new DateTime.fromMillisecondsSinceEpoch(millis));
}

loadSubmissions(Assignment assign, {submissions: null}) async {
    if (submissions == null) {
        submissions = await api.getSubmissions(assign.course, assign.id);
    }
    submissions.sort();
    if (submissions.length == 0) {
        alert('No submissions are available for ${assign.course}/${assign.id}');
        return;
    }
    var results = null;
    var directory = '${assign.course}-${assign.id}';
    bool canBatchGrade  =false;
    if (socketConnected) {
        var tree = await getDirectoryTree();
        if (tree.containsKey(directory) && tree[directory] is Map &&
                tree[directory].containsKey('results.json') && tree[directory]['results.json'] == 'results.json') {
            var text = await readFile('$directory/results.json');
            results = JSON.decode(text);
        }
        if (tree.containsKey(directory) && tree[directory] is Map) canBatchGrade = true;
    }
    var sidebar = querySelector('.submission-sidebar');
    sidebar.innerHtml = "";
    var contents = querySelector('.submission-contents');
    contents.innerHtml = "";
    if (results != null) {
        String timestamp = "";
        if (results['timestamp'] is int) {
            timestamp = formatTime(results['timestamp']);
        }
        var item = new DivElement()..classes = ['submission']..innerHtml = 'Batch Grade Results<br>$timestamp';
        showResults([e]){
            querySelectorAll('.submission-selected').classes.remove('submission-selected');
            item.classes.add('submission-selected');
            contents.innerHtml = "";
            contents.append(makeGradeTable(results));
        }
        item.onClick.listen(showResults);
        sidebar.append(item);
        showResults();
    }
    for (var subm in submissions) {
        Student student = students[subm.student];
        String timestamp = formatTime(subm.time);
        if (subm.time > assign.deadline) {
            timestamp += '&nbsp;<span class="label label-danger">Late</span>';
        }
        var item = new DivElement()..classes = ['submission'];
        item.innerHtml = '${student.name}<br>${student.email}<br>$timestamp';
        item.onClick.listen((e){
            querySelectorAll('.submission-selected').classes.remove('submission-selected');
            item.classes.add('submission-selected');
            contents.innerHtml = "";
            if (results != null) {
                contents.append(makeGradeTable(results, withOnly: student.email));
            }
            contents.appendHtml("<b>Note:</b> ${subm.note}");
            for (String filename in subm.files.keys) {
                String data = subm.files[filename];
                data = data.replaceAll("<", "&lt;").replaceAll(">", "&gt;");
                contents.append(new DivElement()..classes=['filename']..innerHtml=filename);
                var pre = new PreElement()..innerHtml = data;
                contents.append(pre);
                context['hljs'].callMethod('highlightBlock', [pre]);
            }
        });
        sidebar.append(item);
    }
    querySelector('.download-subm').onClick.listen((e) async {
        alert('Saving submissions...', 'info');
        await saveSubmissions(assign.downloadCode, directory, submissions);
        alert('Submissions downloaded to $clientDirectory/$directory.', 'success');
        canBatchGrade = true;
    });
    querySelector('.batch-grade').onClick.listen((e) async {
        if (canBatchGrade) {
            alert('Grading submissions...', 'info');
            var results = await batchGrade(directory);
            await writeFile('$directory/results.json', JSON.encode(results));
            loadSubmissions(assign, submissions: submissions);
            alert('Submissions graded.', 'success');
        } else {
            alert('You must download submissions before grading them.');
        }
    });
    querySelector('.download-batch').onClick.listen((e) async {
        alert('Saving submissions...', 'info');
        await saveSubmissions(assign.downloadCode, directory, submissions);
        canBatchGrade = true;
        alert('Grading submissions...', 'info');
        var results = await batchGrade(directory);
        await writeFile('$directory/results.json', JSON.encode(results));
        loadSubmissions(assign, submissions: submissions);
        alert('Submissions downloaded and graded.', 'success');
    });
    querySelector('.delete-subm').onClick.listen((e) async {
        // TODO Add deletion API
    });
    switchPage('submissions');
}

makeGradeTable(var results, {String withOnly: null}) {
    var table = new Element.table()..classes=['results-table', 'table', 'table-hover'];
    var thead = new Element.tag('thead');
    var tbody = new Element.tag('tbody');
    table.append(thead);
    table.append(tbody);
    var testList = [];
    var testPoints = [];
    var totalPoints;
    for (var student in results.keys) {
        if (results[student] is Map) {
            for (var test in results[student]['tests']) {
                testList.add(test['name']);
                if (test.containsKey('points')) {
                    if (test['includedInScore']) {
                        testPoints.add("${test['points']} pts");
                    } else {
                        testPoints.add("<i>${test['points']} pts</i>");
                    }
                } else {
                    testPoints.add('P/F');
                }
            }
            totalPoints = results[student]['points'];
            break;
        }
    }
    var heading = new Element.tr()..classes=['results-header'];
    heading.append(new Element.th()..innerHtml = 'Student');
    for (int i = 0; i < testList.length; i++) {
        var test = testList[i];
        var points = testPoints[i];
        heading.append(new Element.th()..innerHtml = '$test<br>$points');
    }
    heading.append(new Element.th()..innerHtml = 'Total<br>$totalPoints');
    thead.append(heading);
    var keys = results.keys;
    if (withOnly != null) {
        keys = [withOnly];
    }
    for (var student in keys) {
        if (student == 'timestamp') continue;
        var row = new Element.tr();
        row.append(new Element.td()..innerHtml = student);
        if (results[student] is Map) {
            for (var test in testList) {
                var stuTest = null;
                for (var s in results[student]['tests']) {
                    if (s['name'] == test) {
                        stuTest = s;
                        break;
                    }
                }
                var result = stuTest['result'];
                var td = new Element.td()..classes = ['results-$result'];
                if (stuTest.containsKey('score')) {
                    td.innerHtml = "${stuTest['score']}";
                } else {
                    td.innerHtml = result == 'passed' ? 'P' : 'F';
                }
                row.append(td);
            }
            int score = results[student]['score'];
            var result = score >= totalPoints ? 'passed' : (score > 0 ? 'partial' : 'failed');
            row.append(new Element.td()..classes = ['results-$result']..innerHtml = '$score');
        } else if(results[student] == 'error') {
            for (int i = 0; i < testList.length + 1; i++) {
                row.append(new Element.td()..innerHtml = 'x'..classes=['results-failed']);
            }
        }
        tbody.append(row);
    }
    return table;
}

alert(String message, [String type = 'danger']) {
    var elem = querySelector('.alert');
    elem.classes = ['alert', 'alert-dismissible', 'alert-$type'];
    elem.style.display = 'block';
    querySelector('.alert-text').innerHtml = message;
    querySelector('.alert-close').onClick.listen((e){
        elem.style.display = 'none'; 
    });
}

loadStudents() async {
    var allStudents = await api.getStudents();
    students = {};
    studentList = [];
    var unenrolled = [];
    for (var s in allStudents) {
        if (s.courses.contains(currentCourse.id)) {
            studentList.add(s);
            students[s.email] = s;
        } else if (currentCourse.allowedStudents.contains(s.email)) {
            unenrolled.add(s);
        }
    }
    studentList.sort();
    var enrolledList = querySelector('.enrolled-students');
    enrolledList.innerHtml = "";
    for (var s in studentList) {
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
    currentPage = page;
    querySelector('.tab-submissions').style.display = page == 'submissions' ? 'block' : 'none';
    querySelectorAll('.page').style.display = 'none';
    querySelector('.page-$page').style.display = 'block';
    querySelectorAll('.tab').classes.remove('active');
    querySelector('.tab-$page').classes.add('active');
}


