import 'dart:html';

import 'package:targets_server/client_api.dart' as api;
import 'package:targets_server/models.dart';
import 'package:targets_server/websocket.dart';

import 'package:redstone_mapper/mapper_factory.dart';

main() {
    bootstrapMapper();
    start();
}    

start() async {
    var info = await api.userInfo();
    (querySelector('#profile') as ImageElement).src = info['image'];
    querySelector('#info').innerHtml = "${info['name']} (${info['email']})";
}