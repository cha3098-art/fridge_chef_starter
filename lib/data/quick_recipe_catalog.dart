import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/quick_recipe.dart';

/// assets/data/quick_recipes.json 을 읽어 QuickRecipe 목록으로 파싱한다.
/// 앱 재시작 전까지는 같은 목록을 재사용하도록 캐시해둔다.
class QuickRecipeCatalog {
  static List<QuickRecipe>? _cache;

  static Future<List<QuickRecipe>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/quick_recipes.json');
    final decoded = json.decode(raw) as List;
    final recipes = decoded
        .map((e) => QuickRecipe.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache = recipes;
    return recipes;
  }
}
