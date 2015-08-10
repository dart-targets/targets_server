library websocket;

import 'dart:html';
import 'dart:convert';
import 'dart:async';

import 'package:redstone_mapper/mapper.dart' as mapper;

WebSocket socket;

String clientDirectory;

String clientVersion;

bool socketConnected = false;

var validVersions = ['0.8', '0.9'];

connectBackground({server: 'ws://localhost.codetargets.com:7620'}) {
    socket = new WebSocket(server);
    socket.onOpen.listen((Event e) {
        socketConnected = true;
        onSocketConnected();
    });
    socket.onMessage.listen((MessageEvent e){
        // msg received
        var msg = JSON.decode(e.data);
        if (msg['type'] == 'log') {
            onSocketLog(sanitize(msg['text']));
        } else if (msg['type'] == 'init') {
            clientDirectory = msg['directory'];
            clientVersion = msg['version'];
            onSocketInitialized(clientDirectory, clientVersion);
        } else if (msg['type'] == 'error') {
            onSocketError(msg['exception']);
        }
    });

    socket.onClose.listen((CloseEvent e) async {
        socketConnected = false;
        onSocketDisconnected();
        if (e.code == 1001) {
            await new Future.delayed(new Duration(seconds: 3));
            connectBackground(server: server);
        }
    });
}

/// like connectBackground, but waits until connection is initialized to return
connect({server: 'ws://localhost:7620'}) async {
    connectBackground(server: server);
    await for (var e in socket.onOpen) break;
    await for (var e in socket.onMessage) {
        var msg = JSON.decode(e.data);
        if (msg['type'] == 'init') {
            return;
        }
    }
}

// UI should rebind these functions
Function onSocketLog = (text) => print(text);
Function onSocketConnected = () => print("Connected to client");
Function onSocketDisconnected = () => print("Disconnected from client");
Function onSocketInitialized = (directory, version) => print("Client version $version initialized in $directory");
Function onSocketError = (error) => print("Socket Error: $error");

int msgCounter = 0;

send(msg) {
    if (socket == null) {
        return null;
    }
    msgCounter++;
    msg['cmd-id'] = msgCounter;
    socket.send(JSON.encode(msg));
    return msgCounter;
}

call(msg) async {
    int id = send(msg);
    await for (var e in socket.onMessage) {
        var resp = JSON.decode(e.data);
        if (resp['type'] == 'response' && 
                resp['command'] == msg['command'] && 
                resp['cmd-id'] == id) {
            return resp;
        }
    }
    return null;
}

sanitize(String msg) {
    msg = msg.replaceAll("\u001b[0;31m", "<span style='color:#ff4444'>");
    msg = msg.replaceAll("\u001b[0;32m", "<span style='color:#44ff44'>");
    msg = msg.replaceAll("\u001b[0;36m", "<span style='color:#57f'>");
    msg = msg.replaceAll("\u001b[0;0m", "</span>");
    return msg;
}

getAssignment(String id, [String url = null]) async {
    await call({
        'command': 'get',
        'assignment': id,
        'url': url
    });
}

runTestsStandard(String assignment) async {
    await call({
        'command': 'test',
        'assignment': assignment
    });
}

runTestsJson(String assignment) async {
    var resp = await call({
        'command': 'test',
        'assignment': assignment,
        'json': true
    });
    return resp['results'];
}

uploadSubmission(String assign, String email, String note) async {
    var resp = await call({
        'command': 'submit',
        'assignment': assign,
        'email': email,
        'note': note
    });
    return resp['hash'];
}

requestUpdate() => send({'command': 'update'});

getDirectoryTree() async {
    var resp = await call({'command': 'directory'});
    return resp['tree'];
}

readFile(String file) async {
    var resp = await call({
        'command': 'read-file',
        'file': file
    });
    return resp['contents'];
}

writeFile(String filename, String contents) async {
    await call({
        'command': 'write-file',
        'file': filename,
        'contents': contents
    });
}

saveSubmissions(String templateId, String directory, var submissions) async {
    await call({
        'command': 'save-submissions',
        'templateId': templateId,
        'directory': directory,
        'submissions': mapper.encode(submissions)
    });
}

batchGrade(String directory) async {
    var resp = await call({
        'command': 'batch-grade',
        'directory': directory
    });
    return resp['results'];
}
