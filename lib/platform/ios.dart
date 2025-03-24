// ignore_for_file: non_constant_identifier_names

import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:xcode_parser1/xcode_parser1.dart';

import '../const/const.dart';
import '../util/log_util.dart';

class FARPlatformIOS {
  String newAppName = '';
  String newAppShortName = '';
  String bundleID_debug = '';
  String bundleID_profile = '';
  String bundleID_release = '';

  late String currentDirPath;

  /// 运行 iOS 工程的替换任务
  Future<void> run({required String dirPath, required YamlMap settings}) async {
    currentDirPath = dirPath;
    if (!settings.containsKey('ios')) {
      log("iOS settings does not contain 'flutter' key.");
      return;
    }

    final iosSettings = settings['ios'] as YamlMap;
    newAppName = iosSettings[keyAppName] ?? '';
    if (newAppName.isEmpty) {
      log("iOS app name is empty.");
      return;
    }

    newAppShortName = iosSettings[keyAppShortName] ?? '';
    if (newAppShortName.isEmpty) {
      newAppShortName = newAppName;
      if (newAppShortName.length > 15) {
        log(
          "iOS app short name can contain up to 15 characters, https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundlename#discussion",
        );
        newAppShortName = '';
      }
    }

    // 更新 Info.plist 文件内容
    _updatePlistFileName();

    dynamic bundleId = iosSettings[keyBundleIdentifier] ?? '';
    if (bundleId is YamlMap) {
      bundleID_debug = bundleId['debug'];
      bundleID_profile = bundleId['profile'];
      bundleID_release = bundleId['release'];
    } else if (bundleId is String) {
      bundleID_debug = bundleId;
      bundleID_profile = bundleId;
      bundleID_release = bundleId;
    }

    // 更新 bundle id
    await _updatePbxprojBundleId();

    log("iOS app name update completed. ✅");
  }

  // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
  void _updatePlistFileName() {
    try {
      final file = File('$currentDirPath/ios/Runner/Info.plist');
      if (!file.existsSync()) {
        log("iOS info.plist does not exist at ${file.path}");
        return;
      }
      final content = file.readAsStringSync();
      final updatedContent = _replacePlistFields(content, {
        'CFBundleName': newAppName,
        'CFBundleDisplayName': newAppShortName,
      });

      file.writeAsStringSync(updatedContent, flush: true);
    } catch (e) {
      log("iOS error updating Info.plist - $e");
    }
  }

  // 更新 bundle id
  Future _updatePbxprojBundleId() async {
    try {
      String filePath = '$currentDirPath/ios/Runner.xcodeproj/project.pbxproj';
      Pbxproj project = await Pbxproj.open(filePath);
      final object = project.find("objects") as MapPbx;
      final configList = object.find("XCConfigurationList") as SectionPbx;
      final buildConfig = object.find("XCBuildConfiguration") as SectionPbx;
      final nativeTarget = configList.childrenList
          .where((element) {
            String tmpComment = element.comment ?? "";
            return tmpComment.contains("PBXNativeTarget") && tmpComment.contains("\"Runner\"");
          })
          .toList()
          .first;
      final buildConfigurations = (nativeTarget as MapPbx).find("buildConfigurations") as dynamic;
      List<String> uuids = [];
      for (var i = 0; i < (buildConfigurations as ListPbx).length; i++) {
        final e = buildConfigurations[i] as ElementOfListPbx;
        uuids.add(e.value);
      }
      final targetBuildConfigs = buildConfig.childrenList.where((e) => uuids.contains(e.uuid)).whereType<MapPbx>().toList();
      for (final mp in targetBuildConfigs) {
        _updateBundleIdForConfiguration(mp);
      }
      await _writeUpdatedProjectFile(filePath, project);
    } catch (e) {
      log("iOS update .pbxproj file fail, error: $e");
    }
  }

  void _updateBundleIdForConfiguration(MapPbx mp) {
    final String? bundleID;
    switch (mp.comment) {
      case 'Debug':
        bundleID = bundleID_debug;
        break;
      case 'Profile':
        bundleID = bundleID_profile;
        break;
      case 'Release':
        bundleID = bundleID_release;
        break;
      default:
        return;
    }
    final buildSettings = mp.find<MapPbx>("buildSettings")!;
    final bundleIdEntry = buildSettings.find<MapEntryPbx>("PRODUCT_BUNDLE_IDENTIFIER")!;
    final bundleValue = bundleIdEntry.value as VarPbx;
    buildSettings.replaceOrAdd(
      bundleIdEntry.copyWith(
        value: bundleValue.copyWith(value: bundleID),
      ),
    );
  }

  Future<void> _writeUpdatedProjectFile(String filePath, Pbxproj project) async {
    final file = File(filePath);
    if (!await file.exists()) {
      await file.create();
    }

    String removeMultipleUTF8String(String input) {
      final utf8Pattern = RegExp(r'^\s*// !\$\*UTF8\*\$!');
      int count = 0;
      String output = input.split('\n').where((line) {
        if (utf8Pattern.hasMatch(line)) {
          return count++ == 0;
        }
        return true;
      }).join('\n');
      return output;
    }

    String projectString = project.formatOutput(project.toString());
    projectString = removeMultipleUTF8String(projectString);
    file.writeAsStringSync(projectString);
  }

  // 替换指定字段的值
  String _replacePlistFields(String content, Map<String, String> replacements) {
    var updatedContent = content;
    replacements.forEach((key, value) {
      final regex = RegExp('<key>$key</key>\\s*<string>.*?</string>');
      if (regex.hasMatch(updatedContent)) {
        updatedContent = updatedContent.replaceAllMapped(
          regex,
          (match) => '<key>$key</key>\n\t<string>$value</string>',
        );
      }
    });
    return updatedContent;
  }
}
