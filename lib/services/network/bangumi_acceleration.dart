import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';

enum BangumiAcceleration {
  direct,
  ech,
  mirror;

  static BangumiAcceleration get current => switch (GStorage.getSetting(
    SettingsKeys.bangumiAcceleration,
  )) {
    'direct' => direct,
    'ech' => ech,
    'mirror' => mirror,
    _ => GStorage.getSetting(SettingsKeys.enableBangumiProxy) ? mirror : direct,
  };

  /// Whether this build carries the mirror credentials, which only official
  /// builds receive through the KAZUMI_* defines.
  static bool get canSignMirrorRequests =>
      bangumiMirrorCredentials['id']!.isNotEmpty &&
      bangumiMirrorCredentials['value']!.isNotEmpty;

  /// Whether the mirror rejects [uri] unless the request is signed: search
  /// and comments.
  static bool mirrorRequiresSignature(Uri uri, String method) {
    if (!ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) {
      return false;
    }
    final path = uri.path;
    if (method == 'POST' && path == '/v0/search/subjects') {
      return true;
    }
    if (method != 'GET') {
      return false;
    }
    return path.startsWith('/p1/subjects/') && path.endsWith('/comments') ||
        path.startsWith('/p1/episodes/') && path.endsWith('/comments') ||
        path.startsWith('/p1/characters/') && path.endsWith('/comments');
  }

  String get label => switch (this) {
    direct => '直连',
    ech => 'ECH',
    mirror => '镜像',
  };
}
