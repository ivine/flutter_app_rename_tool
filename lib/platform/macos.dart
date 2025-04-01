import 'dart:io';

import '../const/const.dart';
import '../const/model.dart';
import '../const/settings.dart';
import '../util/log_util.dart';
import '../util/darwin_util.dart';

class FARPlatformMacOS {
  final platform = FARPlatform.macos;
  late String currentDirPath;
  late FarConfig config;
  String get targetName {
    return config.targetName ?? 'Runner';
  }

  String get bundleDisplayName {
    return config.appName ?? '';
  }

  String get bundleName {
    if (config.bundleName == null) {
      return '';
    }
    String name = config.bundleName ?? bundleDisplayName;
    return name;
  }

  String get copyright {
    return config.copyright ?? '';
  }

  Future<void> run({required String dirPath, required FarConfig farConfig}) async {
    currentDirPath = dirPath;
    config = farConfig;
    if (config.enable == false) {
      logSkipping("$platform - $targetName settings enable is false");
      return;
    }

    renamePlist();
    await renameConfigsAppInfoValues();

    log("$platform $targetName, name update completed. ✅");
  }

  void renamePlist() {
    // bundle display name
    if (bundleDisplayName.isEmpty) {
      logSkipping("$platform $targetName, app name(CFBundleDisplayName) is empty.");
    }

    // bundle name
    String tmpBundleName = bundleName;
    if (bundleName.isEmpty) {
      logSkipping("$platform $targetName, app short name(CFBundleName) is empty");
    }
    if (bundleName.length > 15) {
      tmpBundleName = "";
      log(
        "$platform $targetName, app short name(CFBundleName) can contain up to 15 characters, https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundlename#discussion",
      );
    }

    // 更新 Info.plist 中的 `CFBundleName` 和 `CFBundleDisplayName`
    DarwinUtil.updatePlistName(
      dir: currentDirPath,
      platformName: platform.name,
      targetName: targetName,
      bundleName: tmpBundleName,
      bundleDisplayName: bundleDisplayName,
    );
  }

  // 更新 `AppInfo.xcconfig` 文件中的多个键值
  Future<void> renameConfigsAppInfoValues() async {
    List<DarwinBundleIDSettings> bundleIdSettings = getBundleIDSettings();
    String product_bundle_id = bundleIdSettings.isNotEmpty ? bundleIdSettings.first.bundleId : "";
    final filterList = bundleIdSettings.where((element) => element.buildType == kBuildTypeRelease).toList();
    if (filterList.isNotEmpty) {
      product_bundle_id = filterList.first.bundleId;
    }
    final map = {
      'PRODUCT_NAME': bundleDisplayName,
      'PRODUCT_BUNDLE_IDENTIFIER': product_bundle_id,
      'PRODUCT_COPYRIGHT': copyright,
    };
    if (map.values.every((value) => value.isEmpty)) {
      log("$platform $targetName, All values are empty, skipping...");
      return;
    }

    try {
      final file = File('$currentDirPath/${platform.name}/$targetName/Configs/AppInfo.xcconfig');

      if (!file.existsSync()) {
        logSkipping("$platform $targetName, Configs/AppInfo.xcconfig does not exist at ${file.path}");
        return;
      }

      String content = file.readAsStringSync();
      bool updated = false;

      map.forEach((key, newValue) {
        if (newValue.isNotEmpty) {
          final newContent = content.replaceAllMapped(
            RegExp('(^$key\\s*=\\s*).*\$', multiLine: true),
            (match) => '${match.group(1)}$newValue',
          );

          if (newContent != content) {
            content = newContent;
            updated = true;
            log("$platform $targetName, Updated $key = $newValue");
          }
        } else {
          log("$platform $targetName, Skipping empty value for $key");
        }
      });

      if (updated) {
        file.writeAsStringSync(content, flush: true);
        log("$platform $targetName, Configs/AppInfo.xcconfig updated successfully");
      } else {
        log("$platform $targetName, No changes needed in Configs/AppInfo.xcconfig");
      }
    } catch (e) {
      log("$platform $targetName, error updating Configs/AppInfo.xcconfig: $e");
    }
  }

  List<DarwinBundleIDSettings> getBundleIDSettings() {
    List<DarwinBundleIDSettings> bundleIdSettings = [
      DarwinBundleIDSettings(buildType: kBuildTypeDebug, bundleId: ""),
      DarwinBundleIDSettings(buildType: kBuildTypeProfile, bundleId: ""),
      DarwinBundleIDSettings(buildType: kBuildTypeRelease, bundleId: ""),
    ];
    if (config.bundleId != null) {
      for (var element in bundleIdSettings) {
        element.bundleId = config.bundleId!;
      }
    }

    if (config.bundleIds is Map<String, dynamic>) {
      Map<String, dynamic> map = config.bundleIds as Map<String, dynamic>;
      map.forEach((key, value) {
        bundleIdSettings.add(DarwinBundleIDSettings(buildType: key, bundleId: "$value"));
      });
    }

    bundleIdSettings = bundleIdSettings.where((element) => element.bundleId != "").toList();
    bundleIdSettings = bundleIdSettings.toSet().toList();
    return bundleIdSettings;
  }
}
