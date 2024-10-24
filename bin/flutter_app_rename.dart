import 'package:args/args.dart';
import 'package:flutter_app_rename/flutter_app_rename.dart';

void main(List<String> arguments) {
  var parser = ArgParser();
  parser.addOption('path', abbr: 'p', defaultsTo: '', help: 'flutter project path');
  ArgResults argResults = parser.parse(arguments);
  String path = argResults['path'];
  FlutterAppRename().run(input_dir_path: path);
}
