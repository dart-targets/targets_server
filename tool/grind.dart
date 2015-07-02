import 'package:grinder/grinder.dart';
import 'package:redstone/tasks.dart';

main(List<String> args) {
  task('build', Pub.build);
  task('server_only', deployServer);
  task('deploy_server', deployServer, ['build']);
  task('all', null, ['build', 'deploy_server']);

  startGrinder(args);
}