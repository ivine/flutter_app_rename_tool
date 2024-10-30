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
    // final stringsXmlFile = File(
    //   '$currentDirPath/android/app/src/main/res/values/strings.xml',
    // );

    // if (!stringsXmlFile.existsSync()) {
    //   log(text: "FARPlatformAndroid: strings.xml does not exist at ${stringsXmlFile.path}");
    //   return;
    // }

    // AndroidManifest.xml
    try {
      final manifest = FARPlatformAndroidManifest(currentDirPath, newName, package);
      await manifest.update();
      log(text: "FARPlatformAndroid: AndroidManifest.xml name updated!");
    } catch (e) {
      log(text: "FARPlatformAndroid: Failed to update app_name, e: $e");
    }

    try {
      processBuildGradleBundleId(bundleId: package);
    } catch (e) {
      log(text: "FARPlatformAndroid: Failed to update app/build.gradle bundleId, e: $e");
    }

    try {
      if (package is String && package.isNotEmpty) {
        log(text: "FARPlatformAndroid: start process rename bundle id dir --- code dirs and files...");
        final buildGradleFile = File("$currentDirPath/android/app/build.gradle");
        bool isKotlin = false;
        if (buildGradleFile.existsSync()) {
          final buildGradleFileString = buildGradleFile.readAsStringSync();
          if (buildGradleFileString.contains("\"kotlin-android\"") &&
              buildGradleFileString.contains('kotlinOptions') &&
              buildGradleFileString.contains('src/main/kotlin')) {
            isKotlin = true;
          }
        }
        await processAndroidCodeFileDirectory(currentDirPath: currentDirPath, language: isKotlin ? 'kotlin' : 'java', newPackage: package);
        log(text: "FARPlatformAndroid: process rename bundle id dir --- code dirs and files completed!");
      } else {
        log(text: "FARPlatformAndroid: process rename bundle id dir --- no need to rename dir, new package name: $package");
      }
    } catch (e) {
      log(text: "FARPlatformAndroid: process rename bundle id dir --- error:$e");
    }
    log(text: "FARPlatformAndroid: app name update completed. ✅");
  }

  void processBuildGradleBundleId({required String bundleId}) {
    final buildGradleFile = File("$currentDirPath/android/app/build.gradle");
    if (!buildGradleFile.existsSync()) {
      print("build.gradle is not exist, path: ${buildGradleFile.path}");
      return;
    }
    final buildGradleString = buildGradleFile.readAsStringSync();
    final newPackageIDBuildGradleString = buildGradleString
        .replaceAll(RegExp('applicationId\\s*=?\\s*["\'].*?["\']'), 'applicationId "$bundleId"')
        .replaceAll(RegExp('namespace\\s*=?\\s*["\'].*?["\']'), 'namespace "$bundleId"');
    buildGradleFile.writeAsStringSync(newPackageIDBuildGradleString);
    print('processBuildGradleAppName completed');
  }

  Future<void> processAndroidCodeFileDirectory({
    required String currentDirPath,
    required String language,
    required String newPackage,
  }) async {
    if (newPackage.isEmpty) {
      print('processAndroidCodeFileDirectory, newPackage: $newPackage is empty');
      return;
    }

    final androidDir = Directory('$currentDirPath/android/app/src/main/$language/');
    final androidMainAllFile = androidDir.listSync(recursive: true);
    String mainActivityFilePath = '';
    String mainActivityFileName = 'MainActivity.java';
    if (language == 'kotlin') {
      mainActivityFileName = 'MainActivity.kt';
    }
    for (var element in androidMainAllFile) {
      if (element.path.endsWith(mainActivityFileName)) {
        mainActivityFilePath = element.path;
      }
    }
    if (mainActivityFilePath.isEmpty) {
      print('not found MainActivity file path');
      return;
    }

    String originalPackagePathString = mainActivityFilePath.replaceAll(androidDir.path, '').replaceAll('/$mainActivityFileName', '');
    String newPakcagePathString = newPackage.split('.').join('/');
    if (originalPackagePathString == newPakcagePathString) {
      print('originalPackagePathString: $originalPackagePathString == newPakcagePathString: $newPakcagePathString');
      return;
    }
    String commonPathString = findCommonPath(originalPackagePathString, newPakcagePathString);

    String originalPackageName = originalPackagePathString.split('/').join('.');
    for (var element in androidMainAllFile) {
      // 修改引入头
      final fileType = await FileUtil.getFilePathEntityType(element.path);
      if (fileType == FileSystemEntityType.file) {
        final tmpFile = File(element.path);
        String tmpFileContent = tmpFile.readAsStringSync();
        if (tmpFileContent.contains(originalPackageName)) {
          tmpFileContent = tmpFileContent.replaceAll("package $originalPackageName", 'package $newPackage');
          tmpFile.writeAsStringSync(tmpFileContent);
        }
      }
    }

    final mainActivityFile = File(mainActivityFilePath);
    final mainActivityParentDir = mainActivityFile.parent;
    if (mainActivityParentDir.existsSync()) {
      final newDirPath = '${androidDir.path}/$newPakcagePathString';
      final newDir = Directory(newDirPath);
      if (!newDir.existsSync()) {
        newDir.createSync(recursive: true);
      }
      mainActivityParentDir.renameSync(newDirPath);
    }

    String previousDirName = originalPackagePathString.split('/').where((e) => !commonPathString.contains(e)).toList().firstOrNull ?? '';
    String tmpOriginalDirPath = '/${androidDir.path.split('/').where((element) => element.isNotEmpty).toList().join('/')}';
    if (commonPathString.isNotEmpty) {
      tmpOriginalDirPath += '/$commonPathString';
    }
    if (previousDirName.isNotEmpty) {
      tmpOriginalDirPath += '/$previousDirName';
    }
    final originalDir = Directory(tmpOriginalDirPath);

    if (originalDir.existsSync()) {
      originalDir.deleteSync(recursive: true);
    } else {
      print('originalDir.path --> ${originalDir.path} is not exist');
    }
  }

// 查找两个字符串的公共路径
  String findCommonPath(String str1, String str2) {
    List<String> parts1 = str1.split('/');
    List<String> parts2 = str2.split('/');
    List<String> commonParts = [];
    int minLength = parts1.length < parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < minLength; i++) {
      if (parts1[i] == parts2[i]) {
        commonParts.add(parts1[i]);
      } else {
        break;
      }
    }
    return commonParts.join('/');
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
  }

  late File mainAndroidManifestFile;
  late File debugAndroidManifestFile;
  late File profileAndroidManifestFile;
  late Directory valuesDir;

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
    if (newPackage.isEmpty) {
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
