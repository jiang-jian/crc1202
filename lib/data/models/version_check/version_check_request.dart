/// 版本检查请求模型
class VersionCheckRequest {
  final String deviceId;
  final String currentVersion;

  VersionCheckRequest({
    required this.deviceId,
    required this.currentVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'currentVersion': currentVersion,
    };
  }
}
