import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 알림 배너 초기화/권한 요청/노출을 담당하는 싱글턴.
/// 즉시 알림(댓글 실시간 구독)과 예약 알림(유통기한 임박) 둘 다 이 서비스를 거쳐 나간다.
/// 실제 트리거 시점은 각 도메인 쪽(RealtimeNotificationManager, FridgeStore)에서 결정한다.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    // 기기 실제 타임존을 조회하는 별도 패키지 없이, 앱이 한국어 사용자 대상이라 서울로 고정한다
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

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

  /// 유통기한 D-day 기준으로 특정 날짜 오전 9시에 울리는 예약 알림을 건다.
  /// 이미 지난 시각이면(예: 유통기한이 이미 임박/만료) 예약하지 않는다.
  ///
  /// 정확한 시각 보장이 필요한 alarm(exactAllowWhileIdle)은 Android 12+에서
  /// SCHEDULE_EXACT_ALARM 특수 권한이 필요해 스토어 심사 부담이 크므로,
  /// 음식 리마인더 특성상 몇 분 오차는 무해하다고 보고 inexact 모드를 쓴다.
  Future<void> scheduleExpirationNotification({
    required int id,
    required String ingredientName,
    required DateTime expirationDate,
    required int daysBefore,
  }) async {
    final target = expirationDate.subtract(Duration(days: daysBefore));
    final scheduled = tz.TZDateTime(tz.local, target.year, target.month, target.day, 9);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'fridge_chef_expiration',
      'Fridge Chef Expiration Alerts',
      channelDescription: '식재료 유통기한 임박 알림 채널입니다.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotificationsPlugin.zonedSchedule(
      id,
      '⏰ 식재료 유통기한 임박!',
      daysBefore == 0
          ? "냉장고 속 '$ingredientName'의 유통기한이 오늘까지예요! 얼른 요리해보세요."
          : "냉장고 속 '$ingredientName'의 유통기한이 $daysBefore일 남았어요.",
      scheduled,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'expiration',
    );
  }

  /// 재료가 삭제되거나 유통기한이 바뀌었을 때 이전에 걸어둔 예약 알림을 취소한다.
  Future<void> cancelNotification(int id) async {
    await _localNotificationsPlugin.cancel(id);
  }
}
