import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fridge_item.dart';

/// 내 냉장고 상태 (싱글턴). Supabase의 ingredients/user_ingredients 테이블과 동기화한다.
class FridgeStore extends ChangeNotifier {
  FridgeStore._();
  static final FridgeStore instance = FridgeStore._();

  SupabaseClient get _client => Supabase.instance.client;

  List<FridgeItem> _items = [];
  bool _loaded = false;
  String? _error;

  List<FridgeItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;

  /// 마지막 네트워크 작업에서 발생한 에러 메시지 (성공하면 다시 null로 돌아간다)
  String? get error => _error;

  /// 로그아웃 등으로 세션이 바뀔 때 캐시를 비운다
  void clear() {
    _items = [];
    _loaded = false;
    _error = null;
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
    } catch (e) {
      _error = _describeError(e);
    }
    _loaded = true;
    notifyListeners();
  }

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
