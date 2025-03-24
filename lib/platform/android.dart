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
      log("Android settings does not contain 'android' key, skipping...");
      return;
    }

    final androidSettings = settings['android'] as YamlMap;
    final newName = androidSettings[keyAppName] ?? '';
    final package = androidSettings[keyAndroidPackgeID] ?? '';
    if (newName.isEmpty) {
      log("Android app name is empty.");
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
      log("Android AndroidManifest.xml name updated!");
    } catch (e) {
      log("Android failed to update app_name, e: $e");
    }

    try {
      processBuildGradleBundleId(bundleId: package);
    } catch (e) {
      log("Android failed to update app/build.gradle bundleId, e: $e");
    }

    try {
      if (package is String && package.isNotEmpty) {
        log("Android start process rename bundle id dir --- code dirs and files...");
        await processAndroidCodeFileDirectory(currentDirPath: currentDirPath, newPackage: package);
        log("Android process rename bundle id dir --- code dirs and files completed!");
      } else {
        log("Android process rename bundle id dir --- no need to rename dir, new package name: $package");
      }
    } catch (e) {
      log("Android process rename bundle id dir --- error:$e");
    }
    log("Android app name update completed. ✅");
  }

  void processBuildGradleBundleId({required String bundleId}) {
    final buildGradleFile = File("$currentDirPath/android/app/build.gradle");
    if (!buildGradleFile.existsSync()) {
      log("Android build.gradle is not exist, path: ${buildGradleFile.path}");
      return;
    }
    final buildGradleString = buildGradleFile.readAsStringSync();
    final newPackageIDBuildGradleString = buildGradleString
        .replaceAll(RegExp('applicationId\\s*=?\\s*["\'].*?["\']'), 'applicationId "$bundleId"')
        .replaceAll(RegExp('namespace\\s*=?\\s*["\'].*?["\']'), 'namespace "$bundleId"');
    buildGradleFile.writeAsStringSync(newPackageIDBuildGradleString);
    log('Android processBuildGradleAppName completed');
  }

  Future<void> processAndroidCodeFileDirectory({
    required String currentDirPath,
    required String newPackage,
  }) async {
    if (newPackage.isEmpty) {
      log('Android processAndroidCodeFileDirectory, newPackage: $newPackage is empty');
      return;
    }

    final androidDir = Directory('$currentDirPath/android/app/src/main/');
    final androidMainAllFile = listAllFiles(androidDir)
        .where((element) => !element.contains('android/app/src/main/res/') && (element.endsWith('.java') || element.endsWith('.kt')))
        .toList();
    String mainActivityFilePath = '';
    String mainActivityFileName = 'MainActivity';
    String language = 'java';
    for (String element in androidMainAllFile) {
      String tmpFileName = p.basename(element);
      if (tmpFileName.startsWith(mainActivityFileName)) {
        mainActivityFilePath = element;
        if (tmpFileName.endsWith("$mainActivityFileName.kt")) {
          language = 'kotlin';
        }
        break;
      }
    }

    if (language == 'java') {
      mainActivityFileName += '.java';
    } else if (language == 'kotlin') {
      mainActivityFileName += '.kt';
    }

    if (mainActivityFilePath.isEmpty) {
      log('Android not found MainActivity file path');
      return;
    }

    String originalPackagePathString =
        mainActivityFilePath.replaceAll('${androidDir.path}$language/', '').replaceAll('/$mainActivityFileName', '');
    String newPakcagePathString = newPackage.split('.').join('/');
    if (originalPackagePathString == newPakcagePathString) {
      log('Android originalPackagePathString: $originalPackagePathString == newPakcagePathString: $newPakcagePathString');
      return;
    }

    // 修改引入头
    String originalPackageName = originalPackagePathString.split('/').join('.');
    for (var element in androidMainAllFile) {
      final fileType = await FileUtil.getFilePathEntityType(element);
      if (fileType == FileSystemEntityType.file) {
        final tmpFile = File(element);
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
      final newDirPath = '${androidDir.path}$language/$newPakcagePathString';
      final newDir = Directory(newDirPath);
      if (!newDir.existsSync()) {
        newDir.createSync(recursive: true);
      }
      mainActivityParentDir.renameSync(newDirPath);
    }

    final needToDeleteDir = mainActivityParentDir.parent;
    if (needToDeleteDir.existsSync()) {
      needToDeleteDir.deleteSync();
    } else {
      log('Android needToDeleteDir.path --> ${needToDeleteDir.path} is not exist');
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

  List<String> listAllFiles(Directory dir) {
    final List<String> filePaths = [];

    try {
      final List<FileSystemEntity> entities = dir.listSync(recursive: false, followLinks: false);
      for (var entity in entities) {
        if (entity is File) {
          filePaths.add(entity.path);
        } else if (entity is Directory) {
          // 递归调用
          filePaths.addAll(listAllFiles(entity));
        }
      }
    } catch (e) {
      log('Android Error listing files in ${dir.path}: $e');
    }
    return filePaths;
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
      log("Android update ${file.path} completed");
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
