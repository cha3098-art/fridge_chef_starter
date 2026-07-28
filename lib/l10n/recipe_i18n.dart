import '../models/recipe.dart';
import '../services/locale_store.dart';
import 'tr.dart';

/// 레시피 카탈로그에서 실제로 쓰이는 재료 이름 전체(41종)의 한->영 사전.
/// 화면 표시에만 쓰고, 냉장고 재료 매칭 비교(fridgeIngredientNames.contains)에는
/// 절대 쓰지 않는다 — 매칭은 항상 원본 한글 이름(RecipeIngredient.name)으로 이루어진다.
const _ingredientNameDictionary = <String, String>{
  '간장': 'Soy sauce',
  '감자': 'Potato',
  '계란': 'Egg',
  '고구마': 'Sweet potato',
  '고등어': 'Mackerel',
  '고사리': 'Fernbrake (gosari)',
  '고추장': 'Gochujang',
  '고춧가루': 'Gochugaru',
  '김': 'Dried seaweed',
  '김치': 'Kimchi',
  '너구리': 'Neoguri noodles',
  '단무지': 'Pickled radish',
  '닭가슴살': 'Chicken breast',
  '닭다리살': 'Chicken thigh',
  '대파': 'Green onion',
  '당근': 'Carrot',
  '당면': 'Glass noodles',
  '돼지고기 목살': 'Pork collar',
  '돼지고기 앞다리살': 'Pork shoulder',
  '된장': 'Doenjang',
  '두부': 'Tofu',
  '떡': 'Rice cake',
  '라면사리': 'Instant ramyeon noodles',
  '마늘': 'Garlic',
  '마요네즈': 'Mayonnaise',
  '무': 'Radish',
  '미역': 'Miyeok (seaweed)',
  '밀가루': 'Flour',
  '밥': 'Cooked rice',
  '버터': 'Butter',
  '부침가루': 'Pancake mix',
  '삼겹살': 'Pork belly',
  '새우': 'Shrimp',
  '생강': 'Ginger',
  '설탕': 'Sugar',
  '소고기 갈비': 'Beef short rib',
  '소고기 등심': 'Beef sirloin',
  '소고기 양지': 'Beef brisket',
  '소금': 'Salt',
  '소시지': 'Sausage',
  '순두부': 'Soft tofu',
  '슬라이스치즈': 'Sliced cheese',
  '시금치': 'Spinach',
  '식용유': 'Cooking oil',
  '쌈장': 'Ssamjang',
  '애호박': 'Zucchini',
  '양배추': 'Cabbage',
  '양파': 'Onion',
  '어묵': 'Fish cake',
  '오징어': 'Squid',
  '올리브유': 'Olive oil',
  '우유': 'Milk',
  '진미채': 'Dried shredded squid',
  '청양고추': 'Cheongyang chili pepper',
  '콩나물': 'Soybean sprouts',
  '짜파게티': 'Chapagetti noodles',
  '참기름': 'Sesame oil',
  '통깨': 'Sesame seeds',
  '햄': 'Ham',
  '후추': 'Pepper',
};

/// 레시피 재료 이름을 현재 언어에 맞게 표시한다(매칭용 아님, 표시 전용).
String trIngredientName(String ko) => tr(ko, _ingredientNameDictionary[ko] ?? ko);

/// 카탈로그에서 실제로 쓰이는 계량 단위의 한->영 사전. g은 온스로 실제 수치를
/// 환산하고(_gramsToOunces), 개/마리는 영어에서 단위 없이 숫자만 쓰므로 별도 처리한다.
const _unitLabelDictionary = <String, String>{
  '단': 'bunch',
  '작은술': 'tsp',
  '큰술': 'tbsp',
  '컵': 'cup',
  '공기': 'bowl',
  '모': 'block',
  '봉': 'pack',
  '장': 'sheet',
  '줄': 'pack',
  '꼬집': 'pinch',
};

const _gramsToOunces = 0.035274;

/// 재료 수량+단위를 현재 언어에 맞게 포맷한다.
/// 한글: 기존과 동일하게 "200g", "1/2단" 형태. 영어: g은 oz로 실제 환산하고,
/// 개/마리는 단위 없이 숫자만(예: "2 Eggs" 대신 "2"), 나머지는 "1 tbsp"처럼 단위를 붙인다.
String localizedQuantity(double quantity, String koUnit) {
  if (LocaleStore.instance.isKorean) {
    return '${formatRecipeAmount(quantity)}$koUnit';
  }
  if (koUnit == 'g') {
    return '${formatRecipeAmount(quantity * _gramsToOunces)} oz';
  }
  if (koUnit == 'ml' || koUnit == '개' || koUnit == '마리') {
    final suffix = koUnit == 'ml' ? ' ml' : '';
    return '${formatRecipeAmount(quantity)}$suffix';
  }
  final enUnit = _unitLabelDictionary[koUnit] ?? koUnit;
  return '${formatRecipeAmount(quantity)} $enUnit';
}

/// RecipeIngredient에 언어별 수량 표시를 붙여주는 확장 — 화면에서는 항상
/// 이 메서드를 쓰고, quantityLabelForServings()(한글 전용)는 모델 내부용으로만 남긴다.
extension RecipeIngredientI18n on RecipeIngredient {
  String localizedQuantityLabelForServings(int servings) =>
      localizedQuantity(quantity * servings, unit);
}

/// RecipeStep의 타이머를 현재 언어에 맞게 "1분 30초" / "1m 30s" 형태로 표시한다.
String? localizedTimerLabel(int? timerSec) {
  if (timerSec == null) return null;
  final m = timerSec ~/ 60;
  final s = timerSec % 60;
  if (LocaleStore.instance.isKorean) {
    if (m == 0) return '$s초';
    if (s == 0) return '$m분';
    return '$m분 $s초';
  }
  if (m == 0) return '${s}s';
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}
