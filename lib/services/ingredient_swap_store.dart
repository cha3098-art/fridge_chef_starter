import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/ingredient_swap_catalog.dart';
import '../models/ingredient_swap.dart';

/// ingredient_swaps 테이블(식재료 대체 룰)을 다루는 싱글턴 스토어.
/// 유료 API 없이 앱에 내장된 기본 룰(ingredient_swap_catalog.dart)만으로 동작한다.
class IngredientSwapStore {
  IngredientSwapStore._();
  static final IngredientSwapStore instance = IngredientSwapStore._();

  SupabaseClient get _client => Supabase.instance.client;

  List<IngredientSwap> _swaps = [];
  bool _loaded = false;

  List<IngredientSwap> get swaps => List.unmodifiable(_swaps);
  bool get isLoaded => _loaded;

  /// ingredient_swaps 테이블이 비어 있으면 기본 대체 룰 16종을 채워 넣는다.
  /// 앱 실행 시 1회 호출되며, 실패해도 부가 기능이라 조용히 무시한다.
  Future<void> seedDefaultsIfNeeded() async {
    try {
      await _client.from('ingredient_swaps').upsert(
            [for (final s in ingredientSwapCatalog) s.toRow()],
            onConflict: 'original_ingredient,substitute_ingredient',
            ignoreDuplicates: true,
          );
      await loadAll();
    } catch (e) {
      debugPrint('IngredientSwapStore.seedDefaultsIfNeeded failed: $e');
    }
  }

  Future<void> loadAll() async {
    final rows = await _client.from('ingredient_swaps').select();
    _swaps = (rows as List)
        .map((row) => IngredientSwap.fromRow(row as Map<String, dynamic>))
        .toList();
    _loaded = true;
  }
}
