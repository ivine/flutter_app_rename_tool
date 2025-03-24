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

    // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
    DarwinUtil.updatePlistFileName(
      dir: currentDirPath,
      platformName: platformName,
      bundleName: bundleName,
      bundleDisplayName: bundleDisplayName,
    );

    // 更新 bundle id
    DarwinUtil.updatePbxprojBundleId(
      dir: currentDirPath,
      platformName: platformName,
      bundleIdSettings: bundleIdSettings,
    );

    log("iOS app name update completed. ✅");
  }
}
