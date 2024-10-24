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
      log(text: "FARPlatformFlutter: settings does not contain 'flutter' key.");
      return;
    }

    final flutterSettings = settings['flutter'] as YamlMap;
    final name = flutterSettings[keyAppName] ?? '';
    if (name.isEmpty) {
      log(text: "FARPlatformFlutter: App name is empty.");
      return;
    }

    // 读取 `pubspec.yaml` 获取原始名称
    final pubspecFile = File('$currentDirPath/$keyPubspecFileName');
    final originalName = await _getOriginalName(pubspecFile);
    if (originalName.isEmpty) {
      log(text: "FARPlatformFlutter: Original name in pubspec.yaml is empty.");
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
    await _replaceInDirectories(['$currentDirPath/lib', '$currentDirPath/test'], patterns, originalName, name);

    // 更新 `pubspec.yaml` 中的名称
    await _updatePubspecName(pubspecFile, name);

    log(text: "FARPlatformFlutter: App name update completed. ✅");
  }

  Future<String> _getOriginalName(File pubspecFile) async {
    if (!pubspecFile.existsSync()) {
      log(text: "FARPlatformFlutter: pubspec.yaml does not exist.");
      return '';
    }
    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    return yaml['name'] ?? '';
  }

  Future<void> _replaceInDirectories(List<String> directories, List<String> patterns, String originalName, String newName) async {
    for (final dirPath in directories) {
      final directory = Directory(dirPath);
      if (!directory.existsSync()) {
        log(text: "FARPlatformFlutter: Directory does not exist: $dirPath");
        continue;
      }

      final dartFiles = FileUtil.listFilesByExtensions(dirPath, ['dart']);
      log(text: "Processing ${dartFiles.length} files in $dirPath...");

      for (final filePath in dartFiles) {
        final file = File(filePath);
        if (await _replaceInFile(file, patterns, originalName, newName)) {
          log(text: "Updated: $filePath");
        }
      }
    }
  }

  Future<bool> _replaceInFile(File file, List<String> patterns, String originalName, String newName) async {
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

  Future<void> _updatePubspecName(File pubspecFile, String newName) async {
    if (!pubspecFile.existsSync()) {
      log(text: "FARPlatformFlutter: pubspec.yaml does not exist.");
      return;
    }

    final content = await pubspecFile.readAsString();
    final editor = YamlEditor(content);
    editor.update(['name'], newName);
    await pubspecFile.writeAsBytes(utf8.encode(editor.toString()));
  }
}
