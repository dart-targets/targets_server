import 'dart:html';

import 'package:targets_server/models.dart';
import 'package:targets_server/websocket.dart';

main() async {
    // page initializes here
    /*
    
    Sample Usage for websocket library:
    (this downloads the enigma-dart assignment, 
    runs its tests, and then outputs the contents of bombe.dart)
    */
    await connect();
    await getAssignment('dart-targets/enigma/dart');
    await runTests('enigma-dart');
    String contents = await readFile('enigma-dart/bombe.dart');
    print("Contents: $contents");
    
}