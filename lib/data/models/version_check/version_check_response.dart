/// 版本检查响应模型
class VersionCheckResponse {
  final String? latestVersion;
  final String? updateUrl;
  final String? updateDescription;
  final bool? forceUpdate;

  VersionCheckResponse({
    this.latestVersion,
    this.updateUrl,
    this.updateDescription,
    this.forceUpdate,
  });

  factory VersionCheckResponse.fromJson(Map<String, dynamic> json) {
    return VersionCheckResponse(
      latestVersion: json['latestVersion'] as String?,
      updateUrl: json['updateUrl'] as String?,
      updateDescription: json['updateDescription'] as String?,
      forceUpdate: json['forceUpdate'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latestVersion': latestVersion,
      'updateUrl': updateUrl,
      'updateDescription': updateDescription,
      'forceUpdate': forceUpdate,
    };
  }
}
