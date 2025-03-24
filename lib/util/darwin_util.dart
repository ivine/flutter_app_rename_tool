import 'dart:io';

import 'package:xcode_parser1/xcode_parser1.dart';

class DarwinUtil {
  // 替换指定字段的值
  static String replacePlistFields(String content, Map<String, String> replacements) {
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

  static Future<void> writeContentToProjectFile(String filePath, Pbxproj project) async {
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

  // type: Debug/Profile/Release...
  static void updateBundleIdForConfiguration(MapPbx mp, String buildType, String bundleId) {
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
}
