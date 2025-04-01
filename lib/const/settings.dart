class DarwinBundleIDSettings {
  final String buildType; // Debug/Profile/Release...

  DarwinBundleIDSettings({required this.buildType, required this.bundleId});
  String bundleId = "";
}
