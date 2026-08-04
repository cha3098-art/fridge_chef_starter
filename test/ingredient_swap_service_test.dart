import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_chef/models/ingredient_swap.dart';
import 'package:fridge_chef/services/ingredient_swap_service.dart';

void main() {
  const swaps = [
    IngredientSwap(
      originalIngredient: '굴소스',
      substituteIngredient: '간장 1큰술 + 설탕 0.5큰술',
      category: '조미료',
      tip: '감칠맛은 살짝 약해지지만 볶음 요리엔 충분해요.',
    ),
    IngredientSwap(
      originalIngredient: '버터',
      substituteIngredient: '식용유 또는 마가린 동량',
      category: '유제품',
      tip: '고소한 풍미는 약해지지만 볶음/구이엔 무리 없어요.',
    ),
  ];

  test('냉장고에 대체재가 있으면 우선 추천 문구를 반환한다', () {
    final result = IngredientSwapService.suggestFor(
      ingredientName: '굴소스 1큰술',
      fridgeIngredientNames: {'설탕', '계란'},
      swaps: swaps,
    );
    expect(result, hasLength(1));
    expect(result.first.ownedSubstituteName, '설탕');
    expect(result.first.message, contains('현재 회원님의 냉장고에 있는 설탕(으)로 대체 가능해요!'));
  });

  test('냉장고에 대체재가 없으면 일반 대체 문구를 반환한다', () {
    final result = IngredientSwapService.suggestFor(
      ingredientName: '버터',
      fridgeIngredientNames: {'계란'},
      swaps: swaps,
    );
    expect(result.first.ownedSubstituteName, isNull);
    expect(result.first.message, contains('식용유 또는 마가린 동량'));
  });

  test('매칭되는 대체 룰이 없으면 빈 목록', () {
    final result = IngredientSwapService.suggestFor(
      ingredientName: '두부',
      fridgeIngredientNames: {'설탕'},
      swaps: swaps,
    );
    expect(result, isEmpty);
  });
}
