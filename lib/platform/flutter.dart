import 'dart:io';
import 'dart:convert';

import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../const/const.dart';
import '../util/log_util.dart';
import '../util/file_util.dart';

class FARPlatformFlutter {
  late String currentDirPath;

  Future<void> run({required String dirPath, required YamlMap settings}) async {
    currentDirPath = dirPath;
    if (!settings.containsKey('flutter')) {
      log("Flutter settings does not contain 'flutter' key, skipping...");
      return;
    }

    final flutterSettings = settings['flutter'] as YamlMap;
    final name = flutterSettings[keyAppName] ?? '';
    if (name.isEmpty) {
      log("Flutter app name is empty.");
      return;
    }

    // 读取 `pubspec.yaml` 获取原始名称
    final pubspecFile = File('$currentDirPath/$keyPubspecFileName');
    final originalName = await _getOriginalName(pubspecFile);
    if (originalName.isEmpty) {
      log("Flutter original name in pubspec.yaml is empty.");
      return;
    }

    // 匹配规则：处理 import/export 的单双引号
    final patterns = [
      "import 'package:$originalName/",
      "import \"package:$originalName/",
      "export 'package:$originalName/",
      "export \"package:$originalName/",
    ];

    // 替换 Dart 文件中的包名
    await _update_packageNameInDirectories(['$currentDirPath/lib', '$currentDirPath/test'], patterns, originalName, name);

    // 更新 `pubspec.yaml` 中的名称
    await _update_pubspecName(pubspecFile, name);

    log("Flutter -> name update completed. ✅");
  }

  Future<String> _getOriginalName(File pubspecFile) async {
    if (!pubspecFile.existsSync()) {
      log("Flutter pubspec.yaml does not exist.");
      return '';
    }
    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    return yaml['name'] ?? '';
  }

  Future<void> _update_packageNameInDirectories(
      List<String> directories, List<String> patterns, String originalName, String newName) async {
    for (final dirPath in directories) {
      final directory = Directory(dirPath);
      if (!directory.existsSync()) {
        log("Flutter directory does not exist: $dirPath");
        continue;
      }

      final dartFiles = FileUtil.listFilesByExtensions(dirPath, ['dart']);
      log("Flutter ${dartFiles.length} files in $dirPath...");

      for (final filePath in dartFiles) {
        final file = File(filePath);
        if (await _update_packageNameInFile(file, patterns, originalName, newName)) {
          log("Flutter Updated: $filePath");
        }
      }
    }
  }

  Future<bool> _update_packageNameInFile(File file, List<String> patterns, String originalName, String newName) async {
    if (!file.existsSync()) return false;
    String content = await file.readAsString();
    bool isNeedToUpdate = content.contains(originalName);

    if (isNeedToUpdate) {
      for (String pattern in patterns) {
        if (content.contains(pattern)) {
          isNeedToUpdate = true;
          String toString = pattern.replaceAll(originalName, newName);
          content = content.replaceAll(pattern, toString);
        }
      }
    }
    if (isNeedToUpdate) {
      await file.writeAsString(content, flush: true);
    }
    return isNeedToUpdate;
  }

  Future<void> _update_pubspecName(File pubspecFile, String newName) async {
    if (!pubspecFile.existsSync()) {
      log("Flutter pubspec.yaml does not exist.");
      return;
    }

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    editor.update(['name'], newName);
    await pubspecFile.writeAsBytes(utf8.encode(editor.toString()));
  }
}
