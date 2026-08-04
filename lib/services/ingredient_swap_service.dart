import '../models/ingredient_swap.dart';
import 'ingredient_swap_store.dart';

/// 재료 하나에 대한 대체 추천 결과. 냉장고에 이미 있는 대체재를 찾았다면
/// [ownedSubstituteName]이 채워지고 [message]가 우선 추천 문구로 바뀐다.
class IngredientSwapSuggestion {
  final IngredientSwap swap;
  final String? ownedSubstituteName;

  const IngredientSwapSuggestion({
    required this.swap,
    this.ownedSubstituteName,
  });

  String get message {
    final owned = ownedSubstituteName;
    if (owned != null) {
      return '현재 회원님의 냉장고에 있는 $owned(으)로 대체 가능해요!';
    }
    return '${swap.originalIngredient} 대신 ${swap.substituteIngredient}(으)로 대체할 수 있어요.';
  }
}

/// ingredient_swaps DB(IngredientSwapStore)와 내 냉장고 재료를 교차 검증해
/// 레시피 재료별 대체 추천 문구를 만드는 서비스.
class IngredientSwapService {
  /// substitute_ingredient 문자열("간장 1큰술 + 설탕 0.5큰술")에서 후보 재료명만 뽑아낸다.
  static final _parenthetical = RegExp(r'\(.*?\)');
  static final _leadingWord = RegExp(r'^[가-힣a-zA-Z]+');

  static List<String> _candidateNames(String substituteText) {
    final cleaned = substituteText.replaceAll(_parenthetical, '');
    final segments = cleaned.split(RegExp(r'\+|또는|혹은'));
    return segments
        .map((s) => _leadingWord.firstMatch(s.trim())?.group(0))
        .whereType<String>()
        .toList();
  }

  /// [ingredientName]("대파 1대"처럼 수량이 섞여 있어도 됨)에 대한 대체 추천 목록을 반환한다.
  /// [fridgeIngredientNames]에 대체재가 이미 있다면 우선 추천 문구로 표시된다.
  /// [swaps]를 생략하면 IngredientSwapStore.instance에 로드된 목록을 사용한다.
  static List<IngredientSwapSuggestion> suggestFor({
    required String ingredientName,
    required Set<String> fridgeIngredientNames,
    List<IngredientSwap>? swaps,
  }) {
    final pool = swaps ?? IngredientSwapStore.instance.swaps;
    final matches = pool
        .where((s) => ingredientName.contains(s.originalIngredient))
        .toList();
    return matches.map((swap) {
      final candidates = _candidateNames(swap.substituteIngredient);
      String? owned;
      for (final candidate in candidates) {
        if (fridgeIngredientNames.contains(candidate)) {
          owned = candidate;
          break;
        }
      }
      return IngredientSwapSuggestion(swap: swap, ownedSubstituteName: owned);
    }).toList();
  }
}
