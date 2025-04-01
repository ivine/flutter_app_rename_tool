const keyAppName = "app_name";
const keyPubspecFileName = "pubspec.yaml";

const keyAndroidPackgeID = "package";

const keyDarwinBundleName = "bundle_name";
const keyDarwinBundleId = "bundle_id";

const kBuildTypeDebug = "debug";
const kBuildTypeProfile = "profile";
const kBuildTypeRelease = "release";

const keyCopyRight = "copyright";

const fileNameRunnerPbxproj = "Runner.xcodeproj/project.pbxproj";

enum FARPlatform {
  ios,
  macos,
  web,
  linux,
  android,
  flutter,
  windows,
  ;

  String get name {
    switch (this) {
      case ios:
        return "ios";
      case macos:
        return "macos";
      case web:
        return "web";
      case linux:
        return "linux";
      case android:
        return "android";
      case flutter:
        return "flutter";
      case windows:
        return "windows";
    }
  }
}
