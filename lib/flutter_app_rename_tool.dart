// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'const/const.dart';
import 'const/model.dart';
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

    String pubspecPath = '$current_dir_path/pubspec.yaml';
    pubspec_file_content = File(pubspecPath).readAsStringSync();
    final pubspecContent = loadYaml(pubspec_file_content);
    if (pubspecContent == null || pubspecContent is! YamlMap) {
      log("pubspec content is empty, please check your pubspec.yaml");
      return;
    }

    if (pubspecContent.containsKey('flutter_app_rename_tool')) {
      settings = pubspecContent['flutter_app_rename_tool'];
    } else {
      log("pubspec content is not contain flutter_app_rename_tool");
    }

    if (settings == null) {
      log("flutter app rename tool settings is null");
      return;
    }

    await FARPlatformFlutter().run(dirPath: current_dir_path, settings: settings!);
    for (var config in getPlatformConfigs(FARPlatform.ios)) {
      await FARPlatformIOS().run(dirPath: current_dir_path, farConfig: config);
    }
    await FARPlatformMacOS().run(dirPath: current_dir_path, settings: settings!);
    await FARPlatformAndroid().run(dirPath: current_dir_path, settings: settings!);
    log("🚀 flutter app rename completed. ✅");
  }

  List<FarConfig> getPlatformConfigs(FARPlatform platform) {
    List<FarConfig> configs = [];
    if (settings == null) {
      return configs;
    }
    if (!settings!.containsKey(platform.name)) {
      return configs;
    }
    final iosSettings = settings![platform.name];
    if (iosSettings is YamlMap) {
      final c = FarConfig.fromRawJson(jsonEncode(iosSettings));
      replaceRootAppNameIfNeeded(c);
      configs.add(c);
    } else if (iosSettings is YamlList) {
      for (var element in iosSettings) {
        final c = FarConfig.fromRawJson(jsonEncode(element));
        replaceRootAppNameIfNeeded(c);
        configs.add(c);
      }
    }
    return configs;
  }

  void replaceRootAppNameIfNeeded(FarConfig config) {
    if (settings == null) {
      return;
    }
    String rootAppName = settings![keyAppName] ?? '';
    if ((config.appName ?? "").isEmpty) {
      config.appName = rootAppName;
    }
  }
}
