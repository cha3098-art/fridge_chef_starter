import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fridge_item.dart';
import 'notification_service.dart';

/// 내 냉장고 상태 (싱글턴). Supabase의 ingredients/user_ingredients 테이블과 동기화한다.
class FridgeStore extends ChangeNotifier {
  FridgeStore._();
  static final FridgeStore instance = FridgeStore._();

  SupabaseClient get _client => Supabase.instance.client;

  List<FridgeItem> _items = [];
  bool _loaded = false;
  String? _error;

  /// 이번 세션에서 이미 유통기한 임박 알림을 보낸 재료 id (중복 알림 방지, clear()에서 리셋)
  final Set<String> _expiryNotifiedItemIds = {};

  List<FridgeItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  /// 마지막 네트워크 작업에서 발생한 에러 메시지 (성공하면 다시 null로 돌아간다)
  String? get error => _error;

  /// 로그아웃 등으로 세션이 바뀔 때 캐시를 비운다
  void clear() {
    _items = [];
    _loaded = false;
    _error = null;
    _expiryNotifiedItemIds.clear();
    notifyListeners();
  }

  Future<void> loadItems() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _items = [];
      _loaded = true;
      _error = null;
      notifyListeners();
      return;
    }
    try {
      final rows = await _client
          .from('user_ingredients')
          .select('id, quantity, unit, expiry_date, ingredients(name, category)')
          .eq('user_id', uid)
          .eq('status', 'active')
          .order('added_at');
      _items = (rows as List).map<FridgeItem>((row) {
        final ingredient = row['ingredients'] as Map<String, dynamic>;
        return FridgeItem(
          id: row['id'] as String,
          name: ingredient['name'] as String,
          quantity: (row['quantity'] as num).toDouble(),
          unit: row['unit'] as String? ?? '',
          expiryDate: row['expiry_date'] == null ? null : DateTime.parse(row['expiry_date'] as String),
          category: ingredient['category'] as String? ?? '기타',
        );
      }).toList();
      _error = null;
      _notifyExpiringItems();
      _scheduleExpiryReminders();
    } catch (e) {
      _error = _describeError(e);
    }
    _loaded = true;
    notifyListeners();
  }

  /// 유통기한이 임박(D-3 이내)하거나 지난 재료를 이번 세션에서 처음 발견했을 때 즉시 로컬 알림을 띄운다
  void _notifyExpiringItems() {
    for (final item in _items) {
      final id = item.id;
      if (id == null) continue;
      if (item.ddayLevel == DdayLevel.ok) continue;
      if (!_expiryNotifiedItemIds.add(id)) continue; // 이미 알림을 보낸 재료면 스킵
      NotificationService.instance.showNotification(
        id: id.hashCode,
        title: '유통기한이 얼마 안 남았어요',
        body: '${item.name} · ${item.ddayLabel}',
      );
    }
  }

  /// 유통기한 3일 전 / 당일 오전 9시에 울리는 예약 알림을 각 재료마다 걸어둔다.
  /// 앱이 완전히 꺼져 있어도 기기 자체 스케줄러가 알림을 띄운다.
  /// 같은 id로 다시 걸면 기존 예약을 덮어쓰므로, 목록을 새로고침할 때마다 불러도 중복되지 않는다.
  void _scheduleExpiryReminders() {
    for (final item in _items) {
      final id = item.id;
      final expiry = item.expiryDate;
      if (id == null || expiry == null) continue;
      NotificationService.instance.scheduleExpirationNotification(
        id: expiryScheduleId(id, 3),
        ingredientName: item.name,
        expirationDate: expiry,
        daysBefore: 3,
      );
      NotificationService.instance.scheduleExpirationNotification(
        id: expiryScheduleId(id, 0),
        ingredientName: item.name,
        expirationDate: expiry,
        daysBefore: 0,
      );
    }
  }

  /// 재료 id + daysBefore 조합으로 결정적인 예약 알림 id를 만든다 (scheduleExpirationNotification/cancelNotification 공용)
  static int expiryScheduleId(String itemId, int daysBefore) => '${itemId}_$daysBefore'.hashCode;

  /// 재료 등록 화면에서 담아온 항목들을 user_ingredients에 추가하고 목록을 새로고침한다
  Future<void> addItems(List<FridgeItem> newItems) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      for (final item in newItems) {
        final ingredientRow =
            await _client.from('ingredients').select('id').eq('name', item.name).maybeSingle();
        if (ingredientRow == null) continue; // 카탈로그에 없는 재료는 스킵 (검색 탭은 항상 카탈로그 기반)
        await _client.from('user_ingredients').insert({
          'user_id': uid,
          'ingredient_id': ingredientRow['id'],
          'quantity': item.quantity,
          'unit': item.unit,
          'expiry_date': item.expiryDate?.toIso8601String().substring(0, 10),
          'added_via': 'manual',
        });
      }
      _error = null;
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
    }
    await loadItems();
  }

  /// 냉장고 목록에서 재료 하나를 삭제한다 (스와이프 삭제 등에서 호출)
  Future<void> deleteItem(String id) async {
    final previous = _items;
    _items = _items.where((i) => i.id != id).toList();
    notifyListeners();
    // 재료가 사라졌으니 걸어뒀던 예약 알림도 함께 취소한다 (삭제 실패해도 다음 로드 때 다시 걸리므로 무해)
    NotificationService.instance.cancelNotification(expiryScheduleId(id, 3));
    NotificationService.instance.cancelNotification(expiryScheduleId(id, 0));
    try {
      await _client.from('user_ingredients').delete().eq('id', id);
      _error = null;
    } catch (e) {
      _items = previous; // 실패하면 낙관적 삭제를 되돌린다
      _error = _describeError(e);
      notifyListeners();
    }
  }

  String _describeError(Object e) {
    if (e is PostgrestException) return e.message;
    return '네트워크 오류가 발생했어요. 잠시 후 다시 시도해주세요.';
  }
}
