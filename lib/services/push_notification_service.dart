import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// FCM 기기 토큰 등록/해제와 포그라운드 수신 처리를 담당하는 싱글턴.
/// 실제 발송(supabase/functions/send-push)은 배틀 행동을 완료한 클라이언트가 호출하고,
/// 여기서는 "이 기기가 이 사용자의 알림을 받을 수 있다"는 사실만 device_tokens에 등록해둔다.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  SupabaseClient get _client => Supabase.instance.client;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _registeredForUid;

  /// 로그인 직후 호출한다. 알림 권한을 요청하고, 발급받은 FCM 토큰을 device_tokens에 등록한다.
  /// AuthGate가 StreamBuilder/FutureBuilder 재빌드 때마다 이 메서드를 다시 호출할 수 있어서,
  /// 같은 사용자로 이미 등록을 마쳤으면 다시 하지 않는다(권한 팝업 재요청 방지, 중복 호출 방지).
  Future<void> registerForUser(String userId) async {
    if (_registeredForUid == userId) return;
    _registeredForUid = userId;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(userId, token);

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _saveToken(userId, newToken);
      });

      _foregroundSubscription?.cancel();
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_showForegroundBanner);
    } catch (e) {
      // 에뮬레이터에 Play 서비스가 없거나 권한이 거부돼도 앱의 나머지 기능은 정상 동작해야 한다
      debugPrint('PushNotificationService.registerForUser failed: $e');
    }
  }

  /// 같은 기기를 다른 계정이 이어서 쓸 수 있으므로(예: 로그아웃 후 다른 계정 로그인),
  /// 같은 토큰이 예전 사용자 행으로 남아 잘못된 사람에게 푸시가 가지 않도록 먼저 지운다.
  /// 마지막은 upsert로 — 같은 사용자가 같은 토큰을 다시 등록하는 경우(예: 화면 재빌드로
  /// registerForUser가 중복 호출됨)에도 (user_id, token) 기본키 충돌 없이 그냥 갱신된다.
  Future<void> _saveToken(String userId, String token) async {
    try {
      await _client
          .from('device_tokens')
          .delete()
          .eq('token', token)
          .neq('user_id', userId);
      await _client.from('device_tokens').upsert({
        'user_id': userId,
        'token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('PushNotificationService._saveToken failed: $e');
    }
  }

  void _showForegroundBanner(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    NotificationService.instance.showNotification(
      id: message.hashCode,
      title: notification.title ?? '냉장고 셰프',
      body: notification.body ?? '',
      payload: message.data['battleId'] as String?,
    );
  }

  /// 로그아웃 시 호출한다 — 이 기기에서 더 이상 이 계정으로 푸시를 받지 않도록 정리한다.
  Future<void> unregister() async {
    _registeredForUid = null;
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _client.from('device_tokens').delete().eq('token', token);
      }
    } catch (e) {
      debugPrint('PushNotificationService.unregister failed: $e');
    }
  }
}
