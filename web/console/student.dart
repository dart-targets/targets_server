import 'dart:html';
import 'dart:async';
import 'dart:js';

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

Student student;

List<Assignment> assignments = [];

main() {
    bootstrapMapper();
    Dropdown.use();
    Modal.use();
    Transition.use();
    querySelector('.tab-editor').style.display = 'none';
    loadUserInfo().then((e)=>initUI());
}

loadUserInfo() async {
    userInfo = await api.userInfo();
    (querySelector('.user-image') as ImageElement).src = userInfo['image'];
    querySelector('.user-name').innerHtml = userInfo['name'];
    student = new Student()..email = userInfo['email']..name = userInfo['name'];
    await api.registerStudent(student);
    student = await api.getStudent(userInfo['email']);
    return null;
}

initUI() async {
    switchPage('home');
    querySelector('.socket-reconnect').onClick.listen((e)=>connectToClient());
    querySelector('.socket-update').onClick.listen((e){
        querySelector('.socket-info').innerHtml = 'Updating...';
        requestUpdate();
    });
    querySelector('.alert-close').onClick.listen((e){
        querySelector('.alert').style.display = 'none'; 
    });
    connectToClient();
    for (var page in pages) {
        querySelector('.tab-$page').onClick.listen((e)=>switchPage(page));
    }
    querySelector('.enroll').onClick.listen((e){
        enroll();
    });
    await loadAssignments();
    loadSubmissions();
}

connectToClient() {
    var socketInfo = querySelector('.socket-info');
    onSocketConnected = () {
        loadEditor();
        socketInfo.innerHtml = "Client Connected";
        querySelectorAll('.requires-socket').style.display = 'block';
        querySelectorAll('.socket-btn').classes.remove('disabled');
        closeAlert();
        reloadAssignments();
    };
    onSocketDisconnected = () {
        socketInfo.innerHtml = "Client Disconnected";
        closeAlert();
        querySelectorAll('.requires-socket').style.display = 'none';
        querySelectorAll('.socket-btn').classes.add('disabled');
        if (currentPage == "editor") {
            switchPage('home');
        }
        reloadAssignments();
    };
    onSocketInitialized = (var directory, var version) async {
        bool valid = false;
        for (var v in validVersions) {
            if (version.startsWith(v)) valid = true;
        }
        if (!valid) {
            socketInfo.innerHtml = 'Updating...';
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

loadAssignments() async {
    assignments = await api.getAllAssignments();
    assignments.sort();
    reloadAssignments();
}

reloadAssignments() async {
    if (assignments.length == 0) {
        if (student.courses.length == 0) {
            querySelector('.assignments').innerHtml = "You aren't enrolled in any courses yet. Click the button in the bottom right to enroll.";
        } else querySelector('.assignments').innerHtml = "Assignments will appear here once your teacher posts them.";
        return;
    }
    if (socketConnected) {
        directoryTree = await getDirectoryTree();
    }
    var container = querySelector('.assignments');
    container.innerHtml = "";
    for (var assign in assignments) {
        container.append(makeAssignment(assign));
    }
}

var directoryTree;

Element makeAssignment(Assignment assign) {
    var now = new DateTime.now().millisecondsSinceEpoch;
    var wrapper = new DivElement()..classes = ['assignment-wrapper', 'col-xs-12', 'col-sm-6', 'col-md-4', 'col-lg-3'];
    var item = new DivElement();
    String type;
    if (now < assign.open) {
        type = 'primary';
    } else if (now < assign.deadline) {
        type = 'info';
    } else if (now < assign.close) {
        type = 'warning';
    } else {
        type = 'danger';
    }
    item.classes = ['assignment', 'panel', 'panel-$type'];
    var heading = new DivElement()..classes = ['panel-heading', 'mouseover'];
    var title = new HeadingElement.h3()..classes = ['panel-title'];
    title.innerHtml = assign.course + '/' + assign.id;
    heading.append(title);
    heading.onClick.listen((e){
        window.open(assign.githubUrl, '_blank');
    });
    String open = formatTime(assign.open);
    String deadline = formatTime(assign.deadline);
    String close = formatTime(assign.close);
    var body = new DivElement()..classes = ['panel-body', 'assignment-body'];
    if (type == 'primary') {
        body.appendHtml('<b>Not Yet Open for Submissions</b><br>Opens at $open<br>Due at $deadline');
    } else if (type == 'info' && assign.deadline - now < 12*60*60*1000) {
        body.appendHtml('<b>Open for Submissions</b><br>Due at $deadline<br><b>Due in less than 12 hours</b>');
    } else if (type == 'info'){
        body.appendHtml('<b>Open for Submissions</b><br>Due at $deadline<br>');
    } else if (type == 'warning') {
        body.appendHtml('<b>Deadline Passed</b><br>You can submit until $close, but your submission will be marked late');
    } else if (type == 'danger') {
        body.appendHtml('<b>Closed for Submissions</b><br>You must contact your teacher if you want to submit your assignment.');
    }
    item.append(heading);
    item.append(body);
    if (socketConnected) {
        var footer = new DivElement()..classes = ['panel-footer'];
        footer.style.position = 'relative';
        if (directoryTree.containsKey(assign.id)) {
            var testClasses = ['btn', 'btn-flat', 'btn-$type'];
            var submitClasses = ['btn', 'btn-flat', 'btn-$type'];
            if (type == 'danger' || type == 'primary') {
                testClasses.add('panel-btn');
                submitClasses.add('hide');
            } else {
                testClasses.add('panel-btn-left');
                submitClasses.add('panel-btn-right');
            }
            var test = new ButtonElement()..classes = testClasses..innerHtml = 'Run Tests';
            var submit = new ButtonElement()..classes = submitClasses..innerHtml = 'Submit';
            test.onClick.listen((e){
                testAssignment(assign.id);
            });
            submit.onClick.listen((e){
                submitAssignment(assign);
            });
            footer.append(test);
            footer.append(submit);
        } else {
            var downloadClasses = ['btn', 'btn-flat', 'btn-$type', 'panel-btn'];
            var download = new ButtonElement()..classes = downloadClasses..innerHtml = 'Download Assignment';
            download.onClick.listen((e) async {
                var oldLog = onSocketLog;
                onSocketLog = (str) => alert(str, 'info');
                await getAssignment(assign.downloadCode);
                onSocketLog = oldLog;
                reloadAssignments();
            });
            footer.append(download);
        }
        item.append(footer);
    }
    wrapper.append(item);
    return wrapper;
}

testAssignment(String id) {
    var oldLog = onSocketLog;
    var sep = clientDirectory.contains('\\') ? '\\' : '/';
    var directory = clientDirectory + sep + id;
    querySelector('.test-directory').innerHtml = directory;
    var output = querySelector('.test-output');
    output.innerHtml = "";
    var validator = new NodeValidatorBuilder.common()..allowInlineStyles();
    onSocketLog = (str) => output.appendHtml('\n$str', validator: validator);
    var wrapper = querySelector('.test-output-wrapper');
    wrapper.style.display = 'block';
    bool complete = false;
    runTestsStandard(id).then(([e]){
        complete = true;
        alert('Tests run. Click outside the output window to close it.', 'success');
        onSocketLog = oldLog;
        var listener;
        listener = wrapper.onClick.listen((e){
            if (!querySelector('.test-output-modal').contains(e.target)) {
                wrapper.style.display = 'none';
                closeAlert();
                listener.cancel();
            }
        });
    });
    new Future.delayed(new Duration(seconds: 8)).then(([e]){
        if (!complete && wrapper.style.display == 'block') {
            alert('Tests are taking a while to run. Click outside the output window if you want to close it.', 'warning');
            var listener;
            listener = wrapper.onClick.listen((e){
                if (!querySelector('.test-output-modal').contains(e.target)) {
                    wrapper.style.display = 'none';
                    closeAlert();
                    listener.cancel();
                }
            });
        }
    });
}

submitAssignment(Assignment assign) async {
    var uploadModal = Modal.wire(querySelector('#uploadModal'));
    var listener;
    listener = querySelector('#uploadButton').onClick.listen((e) async {
        listener.cancel();
        var note = (querySelector('#inputNote') as InputElement).value;
        uploadModal.hide();
        alert('Uploading submission...', 'info');
        var validateModal = Modal.wire(querySelector('#validateModal'));
        var hash = await uploadSubmission(assign.id, userInfo['email'], note);
        var subm = await api.getUpload(hash);
        closeAlert();
        var info = querySelector('.validation-info');
        int diff = assign.deadline - new DateTime.now().millisecondsSinceEpoch;
        if (diff <= 0) {
            info.innerHtml = 'The deadline for this assignment has already passed, so your submission will be marked late.';
        } else if (diff <= 1000*60) {
            info.innerHtml = "This assignment is due within the next minute, so it may be marked late if you don't submit soon.";
        } else if (diff <= 1000*60*10) {
            info.innerHtml = "This assignment is due within the next 10 minutes and will be marked late if submitted after the deadline.";
        } else {
            info.innerHtml = "Uploads expire if not submitted within 10 minutes. Your assignment is not submitted until you click the button below.";
        }
        var contents = querySelector('.upload-contents');
        contents.style.height = "${window.innerHeight - 250}px";
        loadSubmission(subm, contents);
        validateModal.show();
        await for(var e in querySelector('#validateButton').onClick) {
            validateModal.hide();
            alert('Submitting...', 'info');
            var result = await api.validateSubmission(hash);
            alert(extractFormatTime(result), 'success');
            loadSubmissions();
            return;
        }
    });
    uploadModal.show();
}

String extractFormatTime(String msg) {
    return msg.replaceAllMapped(new RegExp(r"\b(\d+)"), (match){
        return formatTime(int.parse(match[0]));
    });
}

String formatTime(int millis) {
    var dateformat = new DateFormat('EEE, MMM d, y h:mm a');
    return dateformat.format(new DateTime.fromMillisecondsSinceEpoch(millis));
}

loadSubmissions({submissions: null}) async {
    if (submissions == null) {
        submissions = await api.getStudentSubmissions(userInfo['email']);
    }
    submissions.sort();
    var sidebar = querySelector('.submission-sidebar');
    sidebar.innerHtml = "";
    var contents = querySelector('.submission-contents');
    contents.innerHtml = "";
    for (var subm in submissions) {
        int deadline = -1;
        for (Assignment assign in assignments) {
            if (assign.course == subm.course && assign.id == subm.assignment) {
                deadline = assign.deadline;
                break;
            }
        }
        String timestamp = formatTime(subm.time);
        if (subm.time > deadline && deadline != -1) {
            timestamp += '&nbsp;<span class="label label-danger">Late</span>';
        }
        var item = new DivElement()..classes = ['submission'];
        item.innerHtml = '${subm.course}/${subm.assignment}<br>$timestamp';
        item.onClick.listen((e){
            querySelectorAll('.submission-selected').classes.remove('submission-selected');
            item.classes.add('submission-selected');
            loadSubmission(subm, contents);
        });
        sidebar.append(item);
    }
}

loadSubmission(Submission subm, Element elem) {
    elem.innerHtml = "";
    if (subm.note != null && subm.note != '') {
        elem.appendHtml("<b>Note:</b> ${subm.note}");
    }
    for (String filename in subm.files.keys) {
        String data = subm.files[filename];
        String lang = filename.split('.').last;
        String highlighted = context['hljs'].callMethod('highlight', [lang, data])['value'];
        elem.append(new DivElement()..classes=['filename']..innerHtml=filename);
        var pre = new PreElement()..innerHtml = highlighted;
        elem.append(pre);
    }
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

enroll() async {
    Modal modal = Modal.wire(querySelector('#enrollModal'));
    var group = querySelector('.enroll-group');
    group.innerHtml = "";
    List<Course> courses = await api.getCourses();
    int count = 0;
    for (Course course in courses) {
        if (!student.courses.contains(course.id)) {
            count++;
            var button = new ButtonElement()..classes = ['btn', 'btn-success', 'btn-flat', 'btn-course'];
            button.innerHtml = '${course.name} (${course.id})';
            button.onClick.listen((e) async {
                modal.hide();
                var result = await api.enrollStudent(course.id, userInfo['email']);
                alert(result, 'success');
                loadAssignments();
            });
            group.append(button);
        }
    }
    if (count == 0 && courses.length == 0) {
        alert('No courses available to enroll in.');
    } else if (count == 0) {
        alert("You're already enrolled in all courses available to you.");
    } else {
        modal.show();
    }
}

switchPage(String page) {
    if (currentPage != page) {
        closeAlert();
    }
    if (page == 'editor') {
        editor.reloadTree();
    }
    currentPage = page;
    querySelectorAll('.page').style.display = 'none';
    querySelector('.page-$page').style.display = 'block';
    querySelectorAll('.tab').classes.remove('active');
    querySelector('.tab-$page').classes.add('active');
}
