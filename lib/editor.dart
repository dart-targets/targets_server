import 'dart:html';
import 'dart:convert';
import 'dart:async';

import 'package:ace/ace.dart' as ace;
import 'package:ace/proxy.dart';
import 'package:tree_component/tree_component.dart';

import 'package:targets_server/websocket.dart';

int sidebarWidth = 280;

ace.Editor editor;

var rootElement;

var callback;

var sidebar;

loadEditor(Element element, {whenDone: null}) async {
    TreeNodeComponent.ARROW_RIGHT = "<i class='arrow mdi-navigation-chevron-right'></i>&nbsp;";
    TreeNodeComponent.ARROW_DOWN = "<i class='arrow mdi-navigation-expand-more'></i>&nbsp;";
    rootElement = element;
    callback = whenDone;
    ace.implementation = ACE_PROXY_IMPLEMENTATION;
    sidebar = new DivElement();
    sidebar.classes.add('editor-sidebar');
    element.append(sidebar);
    var tabBar = new DivElement();
    tabBar.classes.add('editor-tabs');
    element.append(tabBar);
    var editElem = new DivElement();
    editElem.classes.add('editor-ace');
    element.append(editElem);
    editor = ace.edit(editElem);
    editor.theme = new ace.Theme('ace/theme/chrome');
    var files = await getDirectoryTree();
    var tree = buildTree(files);
    lastFiles = files;
    tree.buildAt(sidebar);
    element.style.display = 'block';
    document.onKeyDown.listen((e) {
        if (e.keyCode == 83 && e.ctrlKey) {
            e.preventDefault();
            saveFile();
        }
    });
    window.onResize.listen((e)=>refreshTabs());
}

var lastFiles = null;

reloadTree() async {
    var files = await getDirectoryTree();
    if (!treesEqual(files, lastFiles)) {
        var tree = buildTree(files);
        sidebar.innerHtml = "";
        tree.buildAt(sidebar);
    }
    lastFiles = files;
}

treesEqual(var treeA, var treeB) {
    if (treeA is String && treeB is String) {
        return true;
    } else if (treeA is String) {
        return disallowedFile(treeA);
    } else if (treeB is String) {
        return disallowedFile(treeB);
    }
    if (treeA.length != treeB.length) return false;
    for (var key in treeA.keys) {
        if (treeB.containsKey(key)) {
            if (!treesEqual(treeA[key], treeB[key])) {
                return false;
            }
        } else return false;
    }
    return true;
}

buildTree(var files) {
    var roots = [];
    var keys = [];
    for (var key in files.keys) keys.add(key);
    keys.sort();
    for (var key in keys) {
        if (key == "Targets Console.app") continue;
        if (key == "targets_dependencies") continue;
        if (key == "Targets Console.bat") continue;
        if (key == "._Targets Console.app") continue;
        if (disallowedFile(key)) continue;
        var root = new TreeNode.root(key, key);
        if (files[key] is Map) {
            parseFiles(files[key], key, root);
        }
        roots.add(root);
    }
    
    var tree = new TreeComponent.multipleRoots(roots) ;
    tree.margin = 0;
    return tree;
}

parseFiles(var files, String path, TreeNode parent) {
    var keys = [];
    for (var key in files.keys) keys.add(key);
    keys.sort();
    for (var key in keys) {
        if (disallowedFile(key)) continue;
        var node = parent.createChild(key, '$path/$key');
        if (files[key] is Map) {
            parseFiles(files[key], '$path/$key', node);
        } else {
            node.listener = new TreeListener();
        }
    }
}

bool disallowedFile(String filename) {
    if (filename.startsWith('.')) return true;
    var disallowed = ['class', 'png', 'jpeg', 'jpg', 'bmp', 'zip', 'tif', 
        'tiff', 'pdf', 'psd', 'gif', 'exe', 'bat'];
    for (var d in disallowed) {
        if (filename.endsWith('.$d')) return true;
    }
    return false;
}

class TreeListener extends TreeNodeListener {
    
    @override
    onClickAction(TreeNode node) async {
        for (int i = 0; i < tabs.length; i++) {
            Tab tab = tabs[i];
            if (tab.filename == node.id) {
                currentTab = i;
                editor.session = tab.session;
                refreshTabs();
                return;
            }
        }
        var contents = await readFile(node.id);
        var session = ace.createEditSession(contents, new ace.Mode.forFile(node.label));
        session.setOption('wrap', true);
        session.setOption('useSoftTabs', true);
        Tab tab = new Tab()..session = session..filename = node.id..text = contents;
        tab.element = new DivElement()..classes.add('editor-tab');
        tab.element.onClick.listen((e) {
            if (!tabs.contains(tab)) return;
            currentTab = tabs.indexOf(tab);
            editor.session = tab.session;
            refreshTabs();
        });
        session.document.onChange.listen((delta)=>updateContents(tab));
        var name = new SpanElement()..innerHtml = node.label;
        name.classes.add('editor-tab-name');
        tab.element.append(name);
        var actions = new SpanElement();
        actions.classes.add('editor-tab-actions');
        tab.element.append(actions);
        var close = new SpanElement()..innerHtml = '&times;';
        close.classes.add('editor-tab-close');
        close.onClick.listen((e) {
            int index = tabs.indexOf(tab);
            tabs.remove(tab);
            if (index == currentTab) {
                currentTab--;
                if (currentTab < 0) currentTab = 0;
            }
            if (tabs.length == 0) {
                closeEditor();
            } else {
                editor.session = tabs[currentTab].session;
                refreshTabs();
            }
        });
        tab.element.append(close);
        tabs.insert(0, tab);
        currentTab = 0;
        refreshTabs();
        editor.session = session;
    }
    
    @override
    onExpandAction(TreeNode node) => null;
    
    @override
    onCheckAction(TreeNode node) => null;

}

closeEditor() {
    rootElement.innerHtml = "";
    rootElement.style.display = "none";
    if (callback != null) {
        callback();
    }
}

class Tab {
    var session;
    String filename;
    Element element;
    String text;
    bool saved = true;
}

List<Tab> tabs = [];
int currentTab = 0;

refreshTabs() {
    var tabBar = querySelectorAll(".editor-tabs")[0];
    tabBar.innerHtml = "";
    if (tabs.length == 0) return;
    int width = (tabBar.clientWidth / tabs.length).floor();
    for (int i = 0; i < tabs.length; i++) {
        Tab tab = tabs[i];
        tab.element.classes.clear();
        tab.element.classes.add('editor-tab');
        tab.element.querySelector('.editor-tab-actions').innerHtml = "";
        if (currentTab == i) {
            tab.element.classes.add('editor-current-tab');
            addActions(tab);
        }
        if (!tab.saved) {
            tab.element.classes.add('editor-tab-unsaved');
        }
        tab.element.style.width = '${width}px';
        tabBar.append(tab.element);
    }
}

addActions(Tab tab) {
    var actions = tab.element.querySelector('.editor-tab-actions');
    if (!tab.saved) {
        var saveButton = new ButtonElement()..classes = ['btn', 'btn-flat', 'btn-inverse', 'btn-xs']..innerHtml = "Save";
        saveButton.onClick.listen((e){
            saveFile();
        });
        actions.append(saveButton);
        return;
    }
    var ext = tab.filename.split('.').last;
    if (ext == 'java' || ext == 'dart') {
        var runButton = new ButtonElement()..classes = ['btn', 'btn-flat', 'btn-inverse', 'btn-xs']..innerHtml = "Run";
        runButton.onClick.listen((e){
            runOpenFile(tab.filename, ext);
        });
        actions.append(runButton);
    } else if (ext == 'py') {
        var run2Button = new ButtonElement()..classes = ['btn', 'btn-flat', 'btn-inverse', 'btn-xs']..innerHtml = "Run Python 2";
        var run3Button = new ButtonElement()..classes = ['btn', 'btn-flat', 'btn-inverse', 'btn-xs']..innerHtml = "Run Python 3";
        run2Button.onClick.listen((e){
            runOpenFile(tab.filename, 'python2');
        });
        run3Button.onClick.listen((e){
            runOpenFile(tab.filename, 'python3');
        });
        actions.append(run2Button);
        actions.append(run3Button);
    }
}

runOpenFile(String filename, String type) {
    var wrapper = new DivElement()..classes = ['run-output-wrapper'];
    wrapper.appendHtml("<span class='run-msg'>Type arguments, then press enter to execute</span>");
    var close = new ButtonElement()..classes = ['btn', 'btn-default', 'btn-danger', 'run-btn', 'btn-sm']..innerHtml = "Exit";
    close.onClick.listen((e){
        runFileCancel();
        wrapper.style.display = 'none';
    });
    wrapper.append(close);
    var modal = new DivElement()..classes = ['run-output-modal'];
    var pre = new PreElement()..classes = ['run-output-text'];
    //var testDir = new SpanElement()..classes = ['run-directory']..innerHtml = dir;
    wrapper.append(modal);
    modal.append(pre);
    var file = filename.split('/').last;
    if (filename.contains('\\')) file = filename.split('\\').last;
    var runfile = file;
    if (type == 'java') {
        runfile = runfile.split('.').first;
    }
    pre.appendText("\$ $type $runfile ");
    wrapper.onClick.listen((e){
        if (close.contains(e.target)) return;
        if (currentInput != null) currentInput.focus(); 
    });
    var argsInput = new InputElement()..classes = ['run-input'];
    currentInput = argsInput;
    pre.append(argsInput);
    argsInput.onKeyPress.listen((e) async {
        if (e.keyCode == KeyCode.ENTER) {
            wrapper.querySelector('.run-msg').innerHtml = "Running $filename...";
            var args = argsInput.value.trim();
            var newText = pre.text + args + '\n';
            pre.innerHtml = "";
            pre.appendText(newText);
            repositionInput(pre);
            var error = await runFile(filename, type, args);
            if (error != null) {
                pre.appendText(error);
            }
            onRunFileOutput = (List<int> data) => null;
            wrapper.querySelector('.run-msg').innerHtml = "Execution complete.";
        } else {
            argsInput.size = argsInput.value.length;
        }
    });
    wrapper.style.display = 'block';
    new Future.delayed(new Duration(milliseconds: 100)).then(([e])=>argsInput.focus());
    onRunFileOutput = (List<int> data) {
        pre.appendText(process(data));
        var existing = currentInput.value;
        var text = pre.text;
        pre.innerHtml = "";
        pre.appendText(text);
        repositionInput(pre, existing);
    };
    querySelector('body').append(wrapper);
}

var currentInput;

repositionInput(PreElement pre, [String existing=""]) {
    var input = new InputElement()..classes = ['run-input'];
    input.value = existing;
    currentInput = input;
    pre.append(input);
    input.focus();
    input.onKeyPress.listen((e) {
        if (e.keyCode == KeyCode.ENTER) {
            var data = input.value + '\n';
            var codes = UTF8.encode(data);
            runFileInput(codes);
            var text = pre.text + data;
            pre.innerHtml = "";
            pre.appendText(text);
            repositionInput(pre);
        } else {
            input.size = input.value.length;
        }
    });
}



String process(List<int> data) {
    var text = UTF8.decode(data);
    return sanitize(text, withColor: false);
}

updateContents(Tab tab) {
    String toSave = tab.session.value;
    bool old = tab.saved;
    tab.saved = toSave == tab.text;
    if (tab.saved != old) refreshTabs();
}

saveFile() async {
    Tab current = tabs[currentTab];
    if (current.saved) return;
    current.text = current.session.value;
    await writeFile(current.filename, current.text);
    current.saved = true;
    refreshTabs();
}