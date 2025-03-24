// ignore_for_file: non_constant_identifier_names

import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:xcode_parser1/xcode_parser1.dart';

import '../const/const.dart';
import '../const/settings.dart';
import '../util/log_util.dart';
import '../util/darwin_util.dart';

class FARPlatformIOS {
  String bundleDisplayName = '';
  String bundleName = '';

  List<DarwinBundleIDSettings> bundleIdSettings = [];

  late String currentDirPath;

  /// 运行 iOS 工程的替换任务
  Future<void> run({required String dirPath, required YamlMap settings}) async {
    currentDirPath = dirPath;
    if (!settings.containsKey('ios')) {
      log("iOS settings does not contain 'ios' key, skipping...");
      return;
    }

    final iosSettings = settings['ios'] as YamlMap;
    bundleDisplayName = iosSettings[keyAppName] ?? '';
    if (bundleDisplayName.isEmpty) {
      log("iOS app name(CFBundleDisplayName) is empty.");
      return;
    }

    bundleName = iosSettings[keyDarwinBundleName] ?? '';
    if (bundleName.isEmpty) {
      bundleName = bundleDisplayName;
      log(
        "iOS app short name(CFBundleName) is empty",
      );
    }
    if (bundleName.length > 15) {
      log(
        "iOS app short name(CFBundleName) can contain up to 15 characters, https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundlename#discussion",
      );
      bundleName = '';
    }

    // 更新 Info.plist 文件内容
    _update_plistFileName();

    // get bundle id
    dynamic bundleId = iosSettings[keyDarwinBundleId] ?? '';
    if (bundleId is YamlMap) {
      bundleIdSettings = [];
      final tmpKeys = bundleId.keys.toList();
      for (final tmpKey in tmpKeys) {
        bundleIdSettings.add(DarwinBundleIDSettings(buildType: tmpKey, bundleId: bundleId[tmpKey]));
      }
    } else if (bundleId is String) {
      bundleIdSettings = [
        DarwinBundleIDSettings(buildType: keyBuildTypeDebug, bundleId: bundleId),
        DarwinBundleIDSettings(buildType: keyBuildTypeProfile, bundleId: bundleId),
        DarwinBundleIDSettings(buildType: keyBuildTypeRelease, bundleId: bundleId),
      ];
    }

    // 更新 bundle id
    await _update_pbxproj_bundleId();

    log("iOS app name update completed. ✅");
  }

  // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
  void _update_plistFileName() {
    try {
      final file = File('$currentDirPath/ios/Runner/Info.plist');
      if (!file.existsSync()) {
        log("iOS info.plist does not exist at ${file.path}");
        return;
      }
      final content = file.readAsStringSync();
      final updatedContent = DarwinUtil.replacePlistFields(
        content,
        {
          'CFBundleName': bundleName,
          'CFBundleDisplayName': bundleDisplayName,
        },
      );

      file.writeAsStringSync(updatedContent, flush: true);
    } catch (e) {
      log("iOS error updating Info.plist - $e");
    }
  }

  // 更新 bundle id
  Future _update_pbxproj_bundleId() async {
    try {
      String filePath = '$currentDirPath/ios/$fileNameRunnerPbxproj';
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
      await DarwinUtil.writeContentToProjectFile(filePath, project);
    } catch (e) {
      log("iOS update .pbxproj file fail, error: $e");
    }
  }

  void _updateBundleIdForConfiguration(MapPbx mp) {
    String buildTypeString = mp.comment?.toLowerCase() ?? "";
    if (buildTypeString.isEmpty) {
      return;
    }
    List<DarwinBundleIDSettings> settings = bundleIdSettings.where((element) => element.buildType == buildTypeString).toList();
    if (settings.isEmpty) {
      return;
    }
    String bundleId = settings.first.bundleId;
    DarwinUtil.updateBundleIdForConfiguration(mp, buildTypeString, bundleId);
  }
}
