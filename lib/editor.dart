import 'dart:html';

import 'package:ace/ace.dart' as ace;
import 'package:ace/proxy.dart';
import 'package:tree_component/tree_component.dart';

import 'package:targets_server/websocket.dart';

int sidebarWidth = 280;

ace.Editor editor;

var rootElement;

var callback;

loadEditor(Element element, {whenDone: null}) async {
    rootElement = element;
    callback = whenDone;
    ace.implementation = ACE_PROXY_IMPLEMENTATION;
    var sidebar = new DivElement();
    sidebar.classes.add('editor-sidebar');
    element.append(sidebar);
    var tabBar = new DivElement();
    tabBar.classes.add('editor-tabs');
    element.append(tabBar);
    var editElem = new DivElement();
    editElem.classes.add('editor-ace');
    element.append(editElem);
    editor = ace.edit(editElem);
    editor.theme = new ace.Theme('ace/theme/monokai');
    var tree = await buildTree();
    tree.buildAt(sidebar);
    element.style.display = 'block';
    document.onKeyDown.listen((e) {
        if (e.keyCode == 83 && e.ctrlKey) {
            e.preventDefault();
            saveFile();
        }
    });
}

buildTree() async {
    var files = await getDirectoryTree();
    
    var roots = [];
    
    for (var key in files.keys) {
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
    for (var key in files.keys) {
        var node = parent.createChild(key, '$path/$key');
        if (files[key] is Map) {
            parseFiles(files[key], '$path/$key', node);
        } else {
            node.listener = new TreeListener();
        }
    }
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
    int width = (tabBar.clientWidth / tabs.length).round();
    for (int i = 0; i < tabs.length; i++) {
        Tab tab = tabs[i];
        tab.element.classes.clear();
        tab.element.classes.add('editor-tab');
        if (currentTab == i) {
            tab.element.classes.add('editor-current-tab');
        }
        if (!tab.saved) {
            tab.element.classes.add('editor-tab-unsaved');
        }
        tab.element.style.width = '${width}px';
        tabBar.append(tab.element);
    }
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