import 'dart:html';

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
    } else if (treeA is String || treeB is String) {
        return false;
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
        'tiff', 'pdf', 'psd', 'gif'];
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