import 'dart:convert';

class FarConfig {
  bool? enable;
  String? targetName;
  String? appName;
  String? bundleName;
  String? bundleId;
  Map<String, dynamic>? bundleIds;

  FarConfig({
    this.enable,
    this.targetName,
    this.appName,
    this.bundleName,
    this.bundleId,
    this.bundleIds,
  });

  factory FarConfig.fromRawJson(String str) => FarConfig.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory FarConfig.fromJson(Map<String, dynamic> json) => FarConfig(
        enable: json["enable"],
        targetName: json["target_name"],
        appName: json["app_name"],
        bundleName: json["bundle_name"],
        bundleId: json["bundle_id"],
        bundleIds: json["bundle_ids"],
      );

  Map<String, dynamic> toJson() => {
        "enable": enable,
        "target_name": targetName,
        "app_name": appName,
        "bundle_name": bundleName,
        "bundle_id": bundleId,
        "bundle_ids": bundleIds,
      };
}
