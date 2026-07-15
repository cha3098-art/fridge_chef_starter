import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 로컬 알림 배너 초기화/권한 요청/노출을 담당하는 싱글턴.
/// 실제 알림 트리거(댓글 실시간 구독, 유통기한 체크)는 각 도메인 쪽(RealtimeNotificationManager,
/// FridgeStore)에서 이 서비스의 showNotification()을 호출하는 방식으로 붙는다.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Android 13+에서는 별도 런타임 권한 요청이 필요하다
    if (Platform.isAndroid) {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// 기기 화면에 즉시 알림 배너를 노출한다.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fridge_chef_alerts',
      'Fridge Chef Alerts',
      channelDescription: '냉장고 셰프의 댓글/유통기한 알림 채널입니다.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
