import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// 로그인 중인 사용자의 notifications 테이블을 실시간 구독해서, 새로 추가된 행이 생기면
/// NotificationService로 로컬 배너를 띄운다.
///
/// Supabase의 stream()은 변경이 생길 때마다 "현재 전체 스냅샷"을 다시 내려주기 때문에
/// (diff가 아님), 이미 본 id를 추적해두지 않으면 같은 알림이 반복해서 배너로 뜬다.
/// 또한 구독을 처음 시작한 시점에 이미 쌓여있던 미확인 알림들은 과거 알림이므로,
/// 첫 스냅샷은 배너를 띄우지 않고 "이미 본 목록"으로만 기록한다.
class RealtimeNotificationManager {
  RealtimeNotificationManager._();
  static final RealtimeNotificationManager instance = RealtimeNotificationManager._();

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  String? _listeningUserId;
  final Set<String> _seenNotificationIds = {};
  bool _isFirstEmission = true;

  /// 로그인 직후 호출한다. 이미 같은 사용자로 구독 중이면 아무 것도 하지 않는다.
  void startListening() {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || userId == _listeningUserId) return;

    stopListening();
    _listeningUserId = userId;
    _isFirstEmission = true;
    _seenNotificationIds.clear();

    _subscription = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen(
          _handleSnapshot,
          // notifications 테이블이 아직 없거나 네트워크 문제가 있어도 앱 전체가 죽지 않도록 한다
          onError: (Object e) => debugPrint('RealtimeNotificationManager stream error: $e'),
        );
  }

  void _handleSnapshot(List<Map<String, dynamic>> rows) {
    if (_isFirstEmission) {
      _isFirstEmission = false;
      _seenNotificationIds.addAll(rows.map((r) => r['id'] as String));
      return;
    }

    for (final row in rows) {
      final id = row['id'] as String;
      if (_seenNotificationIds.contains(id)) continue;
      _seenNotificationIds.add(id);
      if (row['is_read'] == false) {
        NotificationService.instance.showNotification(
          id: id.hashCode,
          title: row['title'] as String? ?? '냉장고 셰프 알림',
          body: row['body'] as String? ?? '',
          payload: row['related_id'] as String?,
        );
      }
    }
  }

  /// 로그아웃 시 호출해서 구독을 해제한다.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _listeningUserId = null;
  }
}
