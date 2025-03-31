// ignore_for_file: non_constant_identifier_names

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'util/log_util.dart';
import 'platform/flutter.dart';
import 'platform/ios.dart';
import 'platform/android.dart';
import 'platform/macos.dart';

class FlutterAppRename {
  // 原文件
  String pubspec_file_content = '';
  YamlMap? settings;

  // dir
  String current_dir_path = Directory.current.path;

  void run({String input_dir_path = ''}) async {
    if (input_dir_path.isNotEmpty) {
      current_dir_path = input_dir_path;
    }
    await setup();

    if (settings == null) {
      log("settings is null");
      return;
    }

    await FARPlatformFlutter().run(dirPath: current_dir_path, settings: settings!);
    await FARPlatformIOS().run(dirPath: current_dir_path, settings: settings!);
    await FARPlatformAndroid().run(dirPath: current_dir_path, settings: settings!);
    await FARPlatformMacOS().run(dirPath: current_dir_path, settings: settings!);

    log("🚀 update completed. ✅");
  }

  setup() async {
    String pubspecPath = '$current_dir_path/pubspec.yaml';
    pubspec_file_content = File(pubspecPath).readAsStringSync();
    final pubspecContent = loadYaml(pubspec_file_content);
    if (pubspecContent == null) {
      log("setup, pubspec content is empty");
      return;
    }

    if (pubspecContent is YamlMap) {
      if (pubspecContent.containsKey('flutter_app_rename_tool')) {
        settings = pubspecContent['flutter_app_rename_tool'];
      } else {
        log("pubspec content is not contain flutter_app_rename_tool");
      }
    } else {
      log("pubspec content is not YamlMap");
    }
  }
}
