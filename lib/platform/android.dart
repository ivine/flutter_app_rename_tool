import 'dart:io';

import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

import '../const/const.dart';
import '../util/file_util.dart';
import '../util/log_util.dart';

class FARPlatformAndroid {
  late String currentDirPath;

  /// 运行 Android 工程的替换任务
  Future<void> run({required String dirPath, required YamlMap settings}) async {
    currentDirPath = dirPath;
    if (!settings.containsKey('android')) {
      log(text: "FARPlatformAndroid: settings does not contain 'flutter' key.");
      return;
    }

    final androidSettings = settings['android'] as YamlMap;
    final newName = androidSettings[keyAppName] ?? '';
    final package = androidSettings['package'] ?? '';
    if (newName.isEmpty) {
      log(text: "FARPlatformAndroid: App name is empty.");
      return;
    }
    final stringsXmlFile = File(
      '$currentDirPath/android/app/src/main/res/values/strings.xml',
    );

    if (!stringsXmlFile.existsSync()) {
      log(text: "FARPlatformAndroid: strings.xml does not exist at ${stringsXmlFile.path}");
      return;
    }

    // settings
    String originalPackage = '';

    // AndroidManifest.xml
    try {
      final manifest = FARPlatformAndroidManifest(currentDirPath, newName, package);
      originalPackage = manifest.originalPackage;
      await manifest.update();
      log(text: "FARPlatformAndroid: AndroidManifest.xml name updated!");
    } catch (e) {
      log(text: "FARPlatformAndroid: Failed to update app_name, e: $e");
    }

    if (package is String && package.isNotEmpty && originalPackage != package) {
      log(text: "FARPlatformAndroid: start process --- android/app/src/main/kotlin(java)/package --- code dirs and files...");
      processAndroidCodeFileDirectory(
        currentDirPath: currentDirPath,
        language: 'java',
        originalPackage: originalPackage,
        newPackage: package,
      );
      processAndroidCodeFileDirectory(
        currentDirPath: currentDirPath,
        language: 'kotlin',
        originalPackage: originalPackage,
        newPackage: package,
      );
      log(text: "FARPlatformAndroid: process --- android/app/src/main/kotlin(java)/package --- code dirs and files completed!");
    }

    log(text: "FARPlatformAndroid: app name update completed. ✅");
  }

  void processAndroidCodeFileDirectory({
    required String currentDirPath,
    required String language,
    required String originalPackage,
    required String newPackage,
  }) {
    final dirPath = '$currentDirPath/android/app/src/main/$language/${originalPackage.split('.').join('/')}';
    final originalDir = Directory(dirPath);

    if (originalDir.existsSync()) {
      final newDirPath = '$currentDirPath/android/app/src/main/$language/${newPackage.split('.').join('/')}';
      final newDir = Directory(newDirPath);

      if (!newDir.existsSync()) {
        newDir.createSync(recursive: true);
      }

      FileUtil.copyDirectory(originalDir, newDir);
      List<String> allFilePaths = FileUtil.listFilesByExtensions(newDir.path, ['*']);

      for (String fp in allFilePaths) {
        File f = File(fp);
        if (f.existsSync()) {
          String fString = f.readAsStringSync();
          fString = fString.replaceAll("package $originalPackage", "package $newPackage");
          f.writeAsStringSync(fString, flush: true);
        }
      }

      originalDir.deleteSync(recursive: true);
    }
  }
}

class FARPlatformAndroidManifest {
  final String dirPath;
  final String newAppName;
  final String newPackage;
  FARPlatformAndroidManifest(this.dirPath, this.newAppName, this.newPackage) {
    mainAndroidManifestFile = File('$dirPath/android/app/src/main/AndroidManifest.xml');
    debugAndroidManifestFile = File('$dirPath/android/app/src/debug/AndroidManifest.xml');
    profileAndroidManifestFile = File('$dirPath/android/app/src/profile/AndroidManifest.xml');
    valuesDir = Directory('$dirPath/android/app/src/main/res/values');

    originalPackage = getOriginalPackage();
  }

  late File mainAndroidManifestFile;
  late File debugAndroidManifestFile;
  late File profileAndroidManifestFile;
  late Directory valuesDir;
  late String originalPackage;

  //
  String getOriginalPackage() {
    String package = '';
    if (mainAndroidManifestFile.existsSync()) {
      final doc = XmlDocument.parse(mainAndroidManifestFile.readAsStringSync());
      final elements = doc.findAllElements('manifest').toList();
      if (elements.isNotEmpty) {
        XmlElement app = elements.first;
        String tmpPakcage = app.getAttribute("package") ?? '';
        if (tmpPakcage.startsWith('@')) {
          final list = tmpPakcage.split("/");
          final targetKey = list.last;
          package = getValuesDirFileStringValue(attributeName: 'name', targetKey: targetKey);
        } else {
          package = tmpPakcage;
        }
      }
    }
    return package;
  }

  /// 修改 AndroidManifest.xml 中的 android:label
  Future<void> update() async {
    for (final file in [mainAndroidManifestFile, debugAndroidManifestFile, profileAndroidManifestFile]) {
      if (!file.existsSync()) {
        continue;
      }
      XmlDocument doc = XmlDocument.parse(file.readAsStringSync());
      doc = updateManifestAppName(doc);
      doc = updateManifestPackage(doc);
      file.writeAsStringSync(doc.toXmlString());
      log(text: "FARPlatformAndroid: update ${file.path} completed");
    }
  }

  XmlDocument updateManifestAppName(XmlDocument doc) {
    final elements = doc.findAllElements('application').toList();
    if (elements.isEmpty) {
      return doc;
    }
    final targetKeyString = "android:label";
    XmlElement app = elements.first;
    String androidLabel = app.getAttribute(targetKeyString) ?? '';
    if (androidLabel.startsWith('@')) {
      final list = androidLabel.split("/");
      final valueStringsTargetKey = list.last;
      final allFiles = getValueDirFile(names: ['string', 'strings'], extensions: ['xml']);
      for (File f in allFiles) {
        final valueDoc = XmlDocument.parse(f.readAsStringSync());
        setDocStringValue(
          doc: valueDoc,
          name: 'string',
          attributeName: 'name',
          targetKey: valueStringsTargetKey,
          targetValue: newAppName,
          autoFill: true,
        );
        f.writeAsStringSync(valueDoc.toXmlString(pretty: true));
      }
    } else {
      app.setAttribute(targetKeyString, newAppName);
    }
    return doc;
  }

  XmlDocument updateManifestPackage(XmlDocument doc) {
    if (newPackage.isEmpty || newPackage == originalPackage) {
      return doc;
    }
    final elements = doc.findAllElements('manifest').toList();
    if (elements.isEmpty) {
      return doc;
    }
    final targetKeyString = "package";
    XmlElement app = elements.first;
    String androidLabel = app.getAttribute(targetKeyString) ?? '';
    if (androidLabel.startsWith('@')) {
      final list = androidLabel.split("/");
      final valueStringsTargetKey = list.last;
      final allFiles = getValueDirFile(names: ['string', 'strings'], extensions: ['xml']);
      for (File f in allFiles) {
        final valueDoc = XmlDocument.parse(f.readAsStringSync());
        setDocStringValue(
          doc: doc,
          name: 'string',
          attributeName: 'name',
          targetKey: valueStringsTargetKey,
          targetValue: newPackage,
        );
        f.writeAsStringSync(valueDoc.toXmlString());
      }
    } else {
      app.setAttribute(targetKeyString, newPackage);
    }
    return doc;
  }

  String getDocStringValue({
    required XmlDocument doc,
    required String name,
    required String attributeName,
    required String targetKey,
  }) {
    String result = '';
    final list = doc.findAllElements(name).toList();
    for (XmlElement e in list) {
      final v = e.getAttribute(attributeName);
      if (v == targetKey) {
        result = e.innerText;
        break;
      }
    }
    return result;
  }

  void setDocStringValue({
    required XmlDocument doc,
    required String name,
    required String attributeName,
    required String targetKey,
    required String targetValue,
    bool autoFill = false,
  }) {
    List<XmlElement> list = doc.findAllElements(name).toList();
    final targetElements = list.where((e) => e.getAttribute(attributeName) == targetKey).toList();
    if (targetElements.isEmpty) {
      if (autoFill) {
        final newElement = XmlElement(XmlName.fromString(name));
        newElement.setAttribute(attributeName, targetKey);
        newElement.innerText = targetValue;
        list.first.parent?.children.add(newElement);
      }
    } else {
      for (XmlElement e in targetElements) {
        e.innerText = targetValue;
      }
    }
  }

  String getValuesDirFileStringValue({required String attributeName, required String targetKey}) {
    String result = '';
    final allFiles = FileUtil.listFilesByExtensions(valuesDir.path, ['xml']);
    for (final filePath in allFiles) {
      final tmpFile = File(filePath);
      if (!tmpFile.existsSync()) continue;

      final valueDoc = XmlDocument.parse(tmpFile.readAsStringSync());
      result = getDocStringValue(doc: valueDoc, name: 'string', attributeName: attributeName, targetKey: targetKey);
      if (result.isNotEmpty) {
        break;
      }
    }
    return result;
  }

  void setValuesDirFileStringValue({
    required String attributeName,
    required String targetKey,
    required String targetValue,
  }) {
    final allFiles = FileUtil.listFilesByExtensions(valuesDir.path, ['xml']);
    for (final filePath in allFiles) {
      final tmpFile = File(filePath);
      if (!tmpFile.existsSync()) continue;

      final valueDoc = XmlDocument.parse(tmpFile.readAsStringSync());
      setDocStringValue(
        doc: valueDoc,
        name: 'name',
        attributeName: attributeName,
        targetKey: targetKey,
        targetValue: targetValue,
      );
    }
  }

  List<File> getValueDirFile({required List<String> names, required List<String> extensions}) {
    List<File> results = [];
    final allFiles = FileUtil.listFilesByExtensions(valuesDir.path, extensions);
    for (String s in allFiles) {
      final tmpFileName = p.basenameWithoutExtension(s);
      if (!names.contains(tmpFileName)) {
        continue;
      }
      final file = File(s);
      if (!file.existsSync()) {
        continue;
      }
      results.add(file);
    }
    return results;
  }
}
