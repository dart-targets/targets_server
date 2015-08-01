import 'dart:html';

import 'package:targets_server/client_api.dart' as api;
import 'package:targets_server/models.dart';
import 'package:targets_server/websocket.dart';

main() async {
    api.initAPI();
    var info = await api.userInfo();
    querySelector('#profile').src = info['image'];
    querySelector('#info').innerHtml = "${info['name']} (${info['username']})";
}