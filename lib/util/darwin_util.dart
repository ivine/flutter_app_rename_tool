import 'dart:io';

import 'package:xcode_parser1/xcode_parser1.dart';

import '../const/const.dart';
import '../const/settings.dart';
import 'log_util.dart';

class DarwinUtil {
  // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
  static void updatePlistFileName({
    required String dir,
    required String platformName,
    required String bundleName,
    required String bundleDisplayName,
  }) {
    try {
      final file = File('$dir/$platformName/Runner/Info.plist');
      if (!file.existsSync()) {
        log("$platformName info.plist does not exist at ${file.path}");
        return;
      }
      final content = file.readAsStringSync();
      final updatedContent = _replacePlistFields(
        content,
        {
          'CFBundleName': bundleName,
          'CFBundleDisplayName': bundleDisplayName,
        },
      );

      file.writeAsStringSync(updatedContent, flush: true);
    } catch (e) {
      log("$platformName error updating Info.plist: $e");
    }
  }

  // 替换指定字段的值
  static String _replacePlistFields(String content, Map<String, String> replacements) {
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

  // platformName: ios or macos
  static Future updatePbxprojBundleId({
    required String dir,
    required String platformName,
    required List<DarwinBundleIDSettings> bundleIdSettings,
  }) async {
    try {
      String filePath = '$dir/$platformName/$fileNameRunnerPbxproj';
      Pbxproj project = await Pbxproj.open(filePath);
      final configList = project.find("XCConfigurationList") as SectionPbx;
      final buildConfig = project.find("XCBuildConfiguration") as SectionPbx;
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
        String buildTypeString = mp.comment?.toLowerCase() ?? "";
        if (buildTypeString.isEmpty) {
          return;
        }
        List<DarwinBundleIDSettings> settings = bundleIdSettings.where((element) => element.buildType == buildTypeString).toList();
        if (settings.isEmpty) {
          return;
        }
        String bundleId = settings.first.bundleId;
        _updateBundleIdForConfiguration(mp, buildTypeString, bundleId);
      }
      await _writeContentToProjectFile(filePath, project);
    } catch (e) {
      log("$platformName update .pbxproj file fail, error: $e");
    }
  }

  // type: Debug/Profile/Release...
  static void _updateBundleIdForConfiguration(MapPbx mp, String buildType, String bundleId) {
    if (mp.comment != buildType) {
      return;
    }
    final buildSettings = mp.find<MapPbx>("buildSettings")!;
    final bundleIdEntry = buildSettings.find<MapEntryPbx>("PRODUCT_BUNDLE_IDENTIFIER")!;
    final bundleValue = bundleIdEntry.value as VarPbx;
    buildSettings.replaceOrAdd(
      bundleIdEntry.copyWith(
        value: bundleValue.copyWith(value: bundleId),
      ),
    );
  }

  static Future<void> _writeContentToProjectFile(String filePath, Pbxproj project) async {
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
}
