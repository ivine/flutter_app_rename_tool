// ignore_for_file: non_constant_identifier_names
import 'package:yaml/yaml.dart';

import '../const/const.dart';
import '../const/settings.dart';
import '../util/log_util.dart';
import '../util/darwin_util.dart';

class FARPlatformIOS {
  String platformName = 'ios';
  String bundleDisplayName = '';
  String bundleName = '';
  List<DarwinBundleIDSettings> bundleIdSettings = [];

  late String currentDirPath;

  /// 运行 iOS 工程的替换任务
  Future<void> run({required String dirPath, required YamlMap settings}) async {
    currentDirPath = dirPath;
    final setup_suc = _setup(settings: settings);
    if (!setup_suc) {
      return;
    }

    // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
    DarwinUtil.updatePlistFileName(
      dir: currentDirPath,
      platformName: platformName,
      bundleName: bundleName,
      bundleDisplayName: bundleDisplayName,
    );

    // 更新 bundle id
    await DarwinUtil.updatePbxprojBundleId(
      dir: currentDirPath,
      platformName: platformName,
      bundleIdSettings: bundleIdSettings,
    );

    log("$platformName -> name update completed. ✅");
  }

  // return true if success
  bool _setup({required YamlMap settings}) {
    if (!settings.containsKey(platformName)) {
      log("$platformName settings does not contain '$platformName' key, skipping...");
      return false;
    }

    // settings
    final platformSettings = settings[platformName] as YamlMap;
    if (platformSettings['enable'] == false) {
      return false;
    }

    // bundle display name
    bundleDisplayName = platformSettings[keyAppName] ?? '';
    if (bundleDisplayName.isEmpty) {
      log("$platformName app name(CFBundleDisplayName) is empty.");
      return false;
    }

    // bundle name
    bundleName = platformSettings[keyDarwinBundleName] ?? '';
    if (bundleName.isEmpty) {
      bundleName = bundleDisplayName;
      log("$platformName app short name(CFBundleName) is empty, skipping...");
    }
    if (bundleName.length > 15) {
      log(
        "$platformName app short name(CFBundleName) can contain up to 15 characters, https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundlename#discussion",
      );
      bundleName = '';
    }

    // bundle id
    dynamic bundleId = platformSettings[keyDarwinBundleId] ?? '';
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
    return true;
  }
}
