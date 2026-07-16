import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/invite_detail_screen.dart';

/// https://fridgechef.app/invite/{id} 링크를 받아 초대장 상세 화면으로 라우팅한다.
///
/// BuildContext를 앱 수명 내내 스트림 콜백에 들고 있으면(위젯이 dispose된 뒤 재사용될 위험)
/// 불안정하므로, MaterialApp에 꽂아둔 전역 navigatorKey를 통해 라우팅한다.
class DeeplinkManager {
  DeeplinkManager._();
  static final DeeplinkManager instance = DeeplinkManager._();

  final navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> init() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleRouting(initialUri);
    } catch (e) {
      debugPrint('초기 딥링크 파싱 에러: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleRouting,
      onError: (Object err) => debugPrint('스트림 딥링크 에러: $err'),
    );
  }

  void _handleRouting(Uri uri) {
    final segments = uri.pathSegments;
    final inviteIndex = segments.indexOf('invite');
    if (inviteIndex == -1 || inviteIndex + 1 >= segments.length) return;
    final inviteId = segments[inviteIndex + 1];

    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => InviteDetailScreen(inviteId: inviteId)),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
