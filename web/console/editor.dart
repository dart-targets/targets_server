import 'dart:html';

import 'package:targets_server/models.dart';
import 'package:targets_server/websocket.dart';
import 'package:targets_server/editor.dart' as editor;

main() async {
    await connect();
    var editorElement = querySelector("#editor");
    var callback = () {
        querySelector('#reopen').innerHtml = "Click here to reopen editor";
    };
    editor.loadEditor(editorElement, whenDone: callback);
    querySelector("#reopen").onClick.listen((e) {
        editor.loadEditor(editorElement, whenDone: callback);
    });
}

