import 'dart:io';

import 'package:xcode_parser1/xcode_parser1.dart';

import '../const/const.dart';
import '../const/settings.dart';
import 'log_util.dart';

class DarwinUtil {
  // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
  static void updatePlistName({
    required String dir,
    required String platformName,
    required String targetName,
    required String bundleName,
    required String bundleDisplayName,
  }) {
    try {
      final file = File('$dir/$platformName/$targetName/Info.plist');
      if (!file.existsSync()) {
        logSkipping("$platformName - $targetName info.plist does not exist at ${file.path}");
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

  // platformName: ios
  static Future updatePbxprojBundleId({
    required String dir,
    required String platform,
    required String targetName,
    required List<DarwinBundleIDSettings> bundleIdSettings,
  }) async {
    try {
      String filePath = '$dir/$platform/$fileNameRunnerPbxproj';
      Pbxproj project = await Pbxproj.open(filePath);

      List<String> buildConfigurationUuids = getProjectBuildConfigurationUuids(project, targetName);
      List<dynamic> buildConfigurations = [];
      for (String tmpUuid in buildConfigurationUuids) {
        for (var element in project.childrenList) {
          buildConfigurations.addAll(findTargetBuildConfiguration(element, tmpUuid));
        }
      }
      for (var bc in buildConfigurations) {
        if (bc is! MapPbx) {
          continue;
        }
        String buildTypeString = bc.comment?.toLowerCase() ?? "";
        if (buildTypeString.isEmpty) {
          return;
        }
        List<DarwinBundleIDSettings> settings = bundleIdSettings.where((element) => element.buildType == buildTypeString).toList();
        if (settings.isEmpty) {
          return;
        }
        String bundleId = settings.first.bundleId;
        _updateBundleIdForConfiguration(bc, buildTypeString, bundleId);
      }
      await _writeContentToProjectFile(filePath, project);
    } catch (e) {
      log("$platform update .pbxproj file fail, error: $e");
    }
  }

  // type: Debug/Profile/Release...
  static void _updateBundleIdForConfiguration(MapPbx mp, String buildType, String bundleId) {
    String mpBid = mp.comment ?? "";
    if (mpBid.toLowerCase() != buildType.toLowerCase()) {
      return;
    }
    final buildSettings = mp.find<MapPbx>("buildSettings");
    if (buildSettings == null) {
      return;
    }
    if (bundleId.isEmpty) {
      return;
    }
    String keyUUID = "PRODUCT_BUNDLE_IDENTIFIER";
    final newEntryPbx = MapEntryPbx(keyUUID, VarPbx(bundleId));
    buildSettings.replaceOrAdd(
      newEntryPbx,
    );
  }

  static List<String> getProjectBuildConfigurationUuids(Pbxproj project, String targetName) {
    List<dynamic> configList = [];
    for (var element in project.childrenList) {
      configList.addAll(findXCConfigurationList(element, targetName));
    }

    List<String> results = [];
    for (var element in configList) {
      if (element is! MapPbx) {
        continue;
      }

      try {
        final buildConfigurations = element.childrenMap['buildConfigurations'];
        if (buildConfigurations is ListPbx) {
          for (int i = 0; i < buildConfigurations.length; i++) {
            final entry = buildConfigurations[i];
            if (entry is ElementOfListPbx) {
              final value = entry.value;
              results.add(value);
            }
          }
        }
      } catch (_) {}
    }
    return results;
  }

  static dynamic findXCConfigurationList(dynamic element, String targetName) {
    List<dynamic> results = [];
    try {
      if (element is CommentPbx || element is MapEntryPbx) {
        return results;
      }
      for (var v in element.childrenList) {
        if (v.comment == "Build configuration list for PBXNativeTarget \"$targetName\"") {
          results.add(v);
        }
        if (v.childrenList.isNotEmpty) {
          results.addAll(findXCConfigurationList(v, targetName));
        }
      }
    } catch (e) {
      // Handle the case where childrenList is not available
    }
    return results;
  }

  static dynamic findTargetBuildConfiguration(dynamic element, String uuid) {
    List<dynamic> results = [];
    try {
      for (var v in element.childrenList) {
        if (v.uuid == uuid) {
          results.add(v);
        }
        if (v.childrenList.isNotEmpty) {
          results.addAll(findTargetBuildConfiguration(v, uuid));
        }
      }
    } catch (e) {
      // Handle the case where childrenList is not available
    }
    return results;
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
