import 'dart:io';

import 'package:yaml/yaml.dart';

import '../const/const.dart';
import '../const/settings.dart';
import '../util/log_util.dart';
import '../util/darwin_util.dart';

class FARPlatformMacOS {
  String platformName = 'macos';
  String bundleDisplayName = '';
  String bundleName = '';
  List<DarwinBundleIDSettings> bundleIdSettings = [];
  String copyright = '';

  late String currentDirPath;

  Future<void> run({required String dirPath, required YamlMap settings}) async {
    currentDirPath = dirPath;
    final setup_suc = _setup(settings: settings);
    if (!setup_suc) {
      return;
    }

    // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
    DarwinUtil.updatePlistName(
      dir: currentDirPath,
      platformName: platformName,
      bundleName: bundleName,
      bundleDisplayName: bundleDisplayName,
    );

    // 更新 bundle id
    // await DarwinUtil.updatePbxprojBundleId(
    //   dir: currentDirPath,
    //   platformName: platformName,
    //   bundleIdSettings: bundleIdSettings,
    // );

    // 更新 Configs/AppInfo.xcconfig
    String product_bundle_id = bundleIdSettings.isNotEmpty ? bundleIdSettings.first.bundleId : "";
    final filterList = bundleIdSettings.where((element) => element.buildType == kBuildTypeRelease).toList();
    if (filterList.isNotEmpty) {
      product_bundle_id = filterList.first.bundleId;
    }
    await _update_configsAppInfoValues({
      'PRODUCT_NAME': bundleDisplayName,
      'PRODUCT_BUNDLE_IDENTIFIER': product_bundle_id,
      'PRODUCT_COPYRIGHT': copyright,
    });

    log("$platformName -> name update completed. ✅");
  }

  _setup({required YamlMap settings}) {
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
        DarwinBundleIDSettings(buildType: kBuildTypeDebug, bundleId: bundleId),
        DarwinBundleIDSettings(buildType: kBuildTypeProfile, bundleId: bundleId),
        DarwinBundleIDSettings(buildType: kBuildTypeRelease, bundleId: bundleId),
      ];
    }

    // copyright
    copyright = platformSettings[keyCopyRight] ?? '';

    return true;
  }

  // 更新 `AppInfo.xcconfig` 文件中的多个键值
  Future<void> _update_configsAppInfoValues(Map<String, String> updates) async {
    if (updates.values.every((value) => value.isEmpty)) {
      log("$platformName All values are empty, skipping...");
      return;
    }

    try {
      final file = File('$currentDirPath/$platformName/Runner/Configs/AppInfo.xcconfig');

      if (!file.existsSync()) {
        log("$platformName Configs/AppInfo.xcconfig does not exist at ${file.path}");
        return;
      }

      String content = file.readAsStringSync();
      bool updated = false;

      updates.forEach((key, newValue) {
        if (newValue.isNotEmpty) {
          final newContent = content.replaceAllMapped(
            RegExp('(^$key\\s*=\\s*).*\$', multiLine: true),
            (match) => '${match.group(1)}$newValue',
          );

          if (newContent != content) {
            content = newContent;
            updated = true;
            log("$platformName Updated $key = $newValue");
          }
        } else {
          log("$platformName Skipping empty value for $key");
        }
      });

      if (updated) {
        file.writeAsStringSync(content, flush: true);
        log("$platformName Configs/AppInfo.xcconfig updated successfully");
      } else {
        log("$platformName No changes needed in Configs/AppInfo.xcconfig");
      }
    } catch (e) {
      log("$platformName error updating Configs/AppInfo.xcconfig: $e");
    }
  }
}
