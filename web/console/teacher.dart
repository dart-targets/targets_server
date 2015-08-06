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

List<String> pages = ['home', 'submissions', 'editor'];

List<Assignment> assignments = [];

Course currentCourse;

List<Course> courses = [];
List<String> courseIds = [];

List<String> githubCourses = [];

Map<String, Student> students = {};

List<Student> studentList = [];

main() {
    bootstrapMapper();
    Dropdown.use();
    Modal.use();
    Transition.use();
    querySelector('.tab-submissions').style.display = 'none';
    querySelector('.tab-editor').style.display = 'none';
    loadUserInfo().then((e)=>initUI());
}

loadUserInfo() async {
    userInfo = await api.userInfo();
    (querySelector('.user-image') as ImageElement).src = userInfo['image'];
    if (userInfo.containsKey('name') && userInfo['name'] != null) {
        querySelector('.user-name').innerHtml = userInfo['name'];
    } else {
        querySelector('.user-name').innerHtml = userInfo['username'];
    }
    var courseList = querySelector('.course-list');
    courseList.innerHtml = "";
    githubCourses = [userInfo['username']];
    for (var org in userInfo['orgs']) githubCourses.add(org);
    for (var course in githubCourses) {
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
    switchPage('home');
    querySelector('.socket-reconnect').onClick.listen((e)=>connectToClient());
    querySelector('.socket-update').onClick.listen((e){
        querySelector('.socket-info').innerHtml = "Updating...";
        requestUpdate();
    });
    querySelector('.alert-close').onClick.listen((e){
        querySelector('.alert').style.display = 'none'; 
    });
    connectToClient();
    for (var page in pages) {
        querySelector('.tab-$page').onClick.listen((e)=>switchPage(page));
    }
    querySelector('.update-course').onClick.listen((e){
        registerCourse(currentCourse.id, true);
    });
    querySelector('.add-assignment').onClick.listen((e)=>createAssignment());
    await findCourses();
}

connectToClient() {
    var socketInfo = querySelector('.socket-info');
    onSocketConnected = () {
        loadEditor();
        socketInfo.innerHtml = "Client Connected";
        querySelectorAll('.requires-socket').style.display = 'block';
        querySelectorAll('.socket-btn').classes.remove('disabled');
        closeAlert();
    };
    onSocketDisconnected = () {
        socketInfo.innerHtml = "Client Disconnected";
        closeAlert();
        querySelectorAll('.requires-socket').style.display = 'none';
        querySelectorAll('.socket-btn').classes.add('disabled');
        if (currentPage == "editor") {
            switchPage('home');
        }
    };
    onSocketInitialized = (var directory, var version) async {
        bool valid = false;
        for (var v in validVersions) {
            if (version.startsWith(v)) valid = true;
        }
        if (!valid) {
            socketInfo.innerHtml = "Updating...";
            requestUpdate();
        }
    };
    socketInfo.innerHtml = "Loading...";
    connectBackground();
}

loadEditor() {
    var element = querySelector("#editor");
    element.innerHtml = "";
    editor.loadEditor(element, whenDone: loadEditor);
}

findCourses([String preferredCourse]) async {
    courses = await api.getCourses();
    courseIds = [];
    for (var course in courses) courseIds.add(course.id);
    if (courses.length == 0) {
        registerCourse();  
    } else {
        if (preferredCourse == null) {
            if (courseIds.contains(userInfo['username'])) {
                switchCourse(userInfo['username']);
            } else switchCourse(courses[0].id);
        } else switchCourse(preferredCourse);
    }
}

isCourseAdmin(String course) {
    return course == userInfo['username'] || userInfo['ownedOrgs'].contains(course);
}

switchCourse(String courseId) async {
    if (!courseIds.contains(courseId)) {
        registerCourse(courseId);
        return;
    }
    for (var course in courses) {
        if (course.id == courseId) currentCourse = course;
    }
    querySelector('.course-current').innerHtml = currentCourse.id;
    querySelector('.navbar').classes = ['navbar'];
    querySelectorAll('.btn-themed').classes.remove('btn-primary');
    querySelectorAll('.btn-themed').classes.remove('btn-inverse');
    if (isCourseAdmin(courseId)) {
        querySelector('.console-title').innerHtml = "Teacher Console";
        querySelector('.navbar').classes.add('navbar-inverse');
        querySelectorAll('.btn-themed').classes.add('btn-inverse');
        querySelectorAll('.btn-teacher').style.display = 'inline-block';
    } else {
        querySelector('.console-title').innerHtml = "Grader Console";
        querySelector('.navbar').classes.add('navbar-primary');
        querySelectorAll('.btn-themed').classes.add('btn-primary');
        querySelectorAll('.btn-teacher').style.display = 'none';
    }
    querySelector('.course-name').innerHtml = currentCourse.name;
    loadAssignments();
    loadStudents();
}

loadAssignments() async {
    assignments = await api.getAssignments(currentCourse.id);
    assignments.sort();
    var container = querySelector('.assignments');
    container.innerHtml = "";
    for (var assign in assignments) {
        container.append(makeAssignment(assign));
    }
}

Element makeAssignment(Assignment assign) {
    var wrapper = new DivElement()..classes = ['assignment-wrapper', 'col-xs-12', 'col-sm-6', 'col-md-4', 'col-lg-3'];
    var now = new DateTime.now().millisecondsSinceEpoch;
    var item = new DivElement();
    String type;
    if (now < assign.open) {
        type = 'warning';
    } else if (now < assign.deadline) {
        type = 'info';
    } else {
        type = 'success';
    }
    item.classes = ['assignment', 'panel', 'panel-$type'];
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
    template.append(new AnchorElement()..target='_blank'..href=assign.githubUrl..innerHtml=assign.downloadCode);
    body.append(template);
    //body.append(new DivElement()..innerHtml="<b>Note:</b>&nbsp;${assign.note}");
    item.append(heading);
    item.append(body);
    var footer = new DivElement()..classes = ['panel-footer'];
    footer.style.position = 'relative';
    if (isCourseAdmin(currentCourse.id)) {
        var edit = new ButtonElement()..classes = ['btn', 'btn-flat' 'btn-$type', 'panel-btn-left']..innerHtml = 'Edit Assignment';
        var view = new ButtonElement()..classes = ['btn', 'btn-flat' 'btn-$type', 'panel-btn-right']..innerHtml = 'View Submissions';
        view.onClick.listen((e) => loadSubmissions(assign));
        edit.onClick.listen((e) => createAssignment(assign));
        footer.append(edit);
        footer.append(view);
    } else {
        var view = new ButtonElement()..classes = ['btn', 'btn-flat' 'btn-$type', 'panel-btn']..innerHtml = 'View Submissions';
        view.onClick.listen((e) => loadSubmissions(assign));
        footer.append(view);
    }
    item.append(footer);
    wrapper.append(item);
    return wrapper;
}

String formatTime(int millis) {
    var dateformat = new DateFormat('EEE, MMM d, y h:mm a');
    return dateformat.format(new DateTime.fromMillisecondsSinceEpoch(millis));
}

var listener1, listener2, listener3;

loadSubmissions(Assignment assign, {submissions: null}) async {
    if (submissions == null) {
        submissions = await api.getSubmissions(assign.course, assign.id);
    }
    if (submissions.length == 0) {
        alert('No submissions are available for ${assign.course}/${assign.id}');
        return;
    }
    querySelector('.tab-submissions').innerHtml = '<a>Submissions (${assign.id})</a>';
    submissions.sort();
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
            if (subm.note != null && subm.note != '') {
                contents.appendHtml("<b>Note:</b> ${subm.note}");
            }
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
    if (listener1 != null) listener1.cancel();
    if (listener2 != null) listener2.cancel();
    if (listener3 != null) listener3.cancel();
    listener1 = querySelector('.download-subm').onClick.listen((e) async {
        alert('Saving submissions...', 'info');
        await saveSubmissions(assign.downloadCode, directory, submissions);
        alert('Submissions downloaded to $clientDirectory/$directory.', 'success');
        canBatchGrade = true;
    });
    listener2 = querySelector('.batch-grade').onClick.listen((e) async {
        if (canBatchGrade) {
            var oldLog = onSocketLog;
            onSocketLog = (str) => alert(str, 'info');
            alert('Grading submissions...', 'info');
            var results = await batchGrade(directory);
            onSocketLog = oldLog;
            await writeFile('$directory/results.json', JSON.encode(results));
            loadSubmissions(assign, submissions: submissions);
            alert('Submissions graded.', 'success');
        } else {
            alert('You must download submissions before grading them.');
        }
    });
    listener3 = querySelector('.download-batch').onClick.listen((e) async {
        alert('Saving submissions...', 'info');
        await saveSubmissions(assign.downloadCode, directory, submissions);
        canBatchGrade = true;
        var oldLog = onSocketLog;
        onSocketLog = (str) => alert(str, 'info');
        alert('Grading submissions...', 'info');
        var results = await batchGrade(directory);
        onSocketLog = oldLog;
        await writeFile('$directory/results.json', JSON.encode(results));
        loadSubmissions(assign, submissions: submissions);
        alert('Submissions downloaded and graded.', 'success');
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
}

closeAlert() {
    querySelector('.alert').style.display = 'none';
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
        var item = new Element.li();
        item.classes.add('list-group-item');
        item.innerHtml = "${s.name} (${s.email})";
        enrolledList.append(item);
    }
    var unenrolledList = querySelector('.unenrolled-students');
    unenrolledList.innerHtml = "";
    var alreadyRegistered = [];
    for (var s in unenrolled) {
        var item = new Element.li();
        item.classes.add('list-group-item');
        item.innerHtml = "${s.name} (${s.email})";
        unenrolledList.append(item);
        alreadyRegistered.add(s.email);
    }
    currentCourse.allowedStudents.sort();
    for (var s in currentCourse.allowedStudents) {
        if (!s.startsWith('@') && !currentCourse.enrolledStudents.contains(s) &&
                !alreadyRegistered.contains(s)) {
            var item = new Element.li();
            item.classes.add('list-group-item');
            item.innerHtml = s;
            unenrolledList.append(item);
        }
    }
    var allowedDomains = querySelector('.allowed-domains');
    allowedDomains.innerHtml = "";
    for (var s in currentCourse.allowedStudents) {
        if (s.startsWith('@')) {
            var item = new Element.li();
            item.classes.add('list-group-item');
            item.innerHtml = s;
            allowedDomains.append(item);
        }
    }
}

switchPage(String page) {
    if (currentPage != page) {
        closeAlert();
    }
    currentPage = page;
    if (page == 'submissions') {
        querySelector('.tab-submissions').style.display = 'block';
    }
    querySelectorAll('.page').style.display = 'none';
    querySelector('.page-$page').style.display = 'block';
    querySelectorAll('.tab').classes.remove('active');
    querySelector('.tab-$page').classes.add('active');
}

registerCourse([String id, bool updating = false]) {
    if (id != null && id != userInfo['username'] && !userInfo['ownedOrgs'].contains(id)) {
        alert('You must be an owner of the "$id" GitHub organization to register it.');
        return;
    }
    var element = querySelector('#registerCourse');
    if (updating) {
        querySelector('#registerCourseLabel').innerHtml = "Update Course";
        querySelector('#registerCourseButton').innerHtml = "Update";
    } else {
        querySelector('#registerCourseLabel').innerHtml = "Register Course";
        querySelector('#registerCourseButton').innerHtml = "Register";
    }
    var idInput = querySelector('#inputCourseID');
    var nameInput = querySelector('#inputCourseName');
    var studentInput = querySelector('#inputAllowedStudents');
    idInput.innerHtml = '';
    if (id != null) {
        idInput.appendHtml('<option>$id</option>');
        if (updating) {
            nameInput.value = currentCourse.name;
            studentInput.value = currentCourse.allowedStudents.join('\n');
        } else {
            nameInput.value = "";
            studentInput.value = "";
        }
    } else {
        var toRegister = [];
        if (!courseIds.contains(userInfo['username'])) {
            toRegister.add(userInfo['username']);
        }
        for (var courseId in userInfo['ownedOrgs']) {
            if (!courseIds.contains(courseId)) {
                toRegister.add(courseId);
            }
        }
        for (var course in toRegister) {
            idInput.appendHtml('<option>$course</option>');
        }
    }
    Modal modal = Modal.wire(element);
    var listener;
    listener = querySelector("#registerCourseButton").onClick.listen((e) async {
        if (updating) {
            alert('Updating course...', 'info');
        } else alert('Registering course...', 'info');
        String id = idInput.value;
        String name = nameInput.value;
        List<String> allowedStudents = studentInput.value.split("\n");
        Course course = new Course()..id = id..name = name..allowedStudents = allowedStudents;
        var result = await api.registerCourse(course);
        alert(result, 'success');
        listener.cancel();
        await findCourses(id);
        modal.hide();
    });
    modal.show();
}

createAssignment([Assignment current]) {
    var element = querySelector('#registerAssignment');
    Modal modal = Modal.wire(element);
    var label = querySelector('#registerAssignLabel');
    var button = querySelector('#registerAssignButton');
    var url = querySelector('#inputTemplateURL');
    var templateInfo = querySelector('.template-info');
    var open = querySelector('#inputAssignOpen');
    var deadline = querySelector('#inputAssignDeadline');
    var close = querySelector('#inputAssignClose');
    String getId(String url) {
        String dir = url.startsWith('https://') ? url.substring(19) : url.substring(18);
        var parts = dir.split('/');
        if (parts.length == 2) {
            if (parts[1].startsWith('targets-')) {
                return parts[1].substring(8);
            }
        } else if (parts.length >= 5) {
            if (parts.last.startsWith('targets-')) {
                String code = parts[1];
                for (int i = 4; i < parts.length - 1; i++) {
                    code += '-' + parts[i];
                }
                code += '-' + parts.last.substring(8);
                return code;
            }
        }
        return null;
    }
    String getDownloadCode(String url) {
        String dir = url.startsWith('https://') ? url.substring(19) : url.substring(18);
        var parts = dir.split('/');
        String owner = parts[0];
        String ownerCode = currentCourse.id == owner ? owner : '${currentCourse.id}:$owner';
        if (parts.length == 2) {
            if (parts[1].startsWith('targets-')) {
                return ownerCode + '/' + parts[1].substring(8);
            }
        } else if (parts.length >= 5) {
            if (parts.last.startsWith('targets-')) {
                String code = parts[1];
                for (int i = 4; i < parts.length - 1; i++) {
                    code += '/' + parts[i];
                }
                code += '/' + parts.last.substring(8);
                return '$ownerCode/$code';
            }
        }
        return null;
    }
    bool isValid(String url) {
        if (!url.startsWith('https://github.com/') && !url.startsWith('http://github.com/')) {
            return false;
        }
        if (!url.contains('/targets-')) return false;
        if (getDownloadCode(url) == null) return false;
        return true;
    }
    updateInfo([e]){
        var address = url.value;
        if (!isValid(address)) {
            templateInfo.innerHtml = "URL must link to a Targets template on GitHub";
            return;
        }
        var id = getId(address);
        var code = getDownloadCode(address);
        templateInfo.innerHtml = "Assignment ID: $id<br>Download Code: $code";
    }
    url.onChange.listen(updateInfo);
    if (current != null) {
        label.innerHtml = "Update Assignment";
        button.innerHtml = "Update";
        url.value = current.githubUrl;
        updateInfo();
        open.value = new DateTime.fromMillisecondsSinceEpoch(current.open).toIso8601String();
        deadline.value = new DateTime.fromMillisecondsSinceEpoch(current.deadline).toIso8601String();
        close.value = new DateTime.fromMillisecondsSinceEpoch(current.close).toIso8601String();
    } else {
        label.innerHtml = "Create Assignment";
        button.innerHtml = "Create";
        url.value = "";
        updateInfo();
        var now = new DateTime.now();
        now = now.subtract(new Duration(milliseconds: now.millisecond, seconds: now.second));
        open.value = now.toIso8601String();
        deadline.value = now.add(new Duration(days: 7)).toIso8601String();
        close.value = now.add(new Duration(days: 14)).toIso8601String();
    }
    var listener;
    listener = button.onClick.listen((e) async {
        Assignment assign = new Assignment();
        if (!isValid(url.value)) {
            alert('Invalid template URL. Please use the URL of a valid Targets template.');
            return;
        }
        assign.githubUrl = url.value;
        assign.downloadCode = getDownloadCode(url.value);
        assign.id = getId(url.value);
        assign.course = currentCourse.id;
        try {
            assign.open = DateTime.parse(open.value).millisecondsSinceEpoch;
            assign.deadline = DateTime.parse(deadline.value).millisecondsSinceEpoch;
            assign.close = DateTime.parse(close.value).millisecondsSinceEpoch;
        } catch (ex) {
            alert("Invalid timestamp. If you're having trouble with entering timestamp, please use Google Chrome.");
            return;
        }
        if (assign.open >= assign.deadline || assign.deadline > assign.close || assign.open >= assign.close) {
            alert("Assignments must open before their deadline and close after their deadline.");
            return;
        }
        if (current == null) {
            for (Assignment existing in assignments) {
                if (existing.id == assign.id) {
                    alert('An assignment with ID "${assign.id}" already exists in this course.');
                    return;
                }
            }
        }
        listener.cancel();
        var result = await api.registerAssignment(assign);
        alert(result, 'success');
        loadAssignments();
        modal.hide();
    });
    modal.show();
}
