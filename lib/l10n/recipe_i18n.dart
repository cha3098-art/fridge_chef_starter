import '../models/recipe.dart';
import '../services/locale_store.dart';
import 'tr.dart';

/// 레시피 카탈로그에서 실제로 쓰이는 재료 이름 전체(112종)의 한->영 사전.
/// 화면 표시에만 쓰고, 냉장고 재료 매칭 비교(fridgeIngredientNames.contains)에는
/// 절대 쓰지 않는다 — 매칭은 항상 원본 한글 이름(RecipeIngredient.name)으로 이루어진다.
const _ingredientNameDictionary = <String, String>{
  '가쓰오부시': 'Bonito flakes (katsuobushi)',
  '가지': 'Eggplant',
  '간장': 'Soy sauce',
  '갈치': 'Hairtail fish',
  '감자': 'Potato',
  '계란': 'Egg',
  '고구마': 'Sweet potato',
  '고등어': 'Mackerel',
  '고사리': 'Fernbrake (gosari)',
  '고추냉이': 'Wasabi',
  '고추장': 'Gochujang',
  '고춧가루': 'Gochugaru',
  '고형카레': 'Curry roux block',
  '국간장': 'Soup soy sauce (guk-ganjang)',
  '굴소스': 'Oyster sauce',
  '그뤼에르 치즈': 'Gruyère cheese',
  '김': 'Dried seaweed',
  '김치': 'Kimchi',
  '낙지': 'Octopus (nakji)',
  '너구리': 'Neoguri noodles',
  '다진 소고기': 'Ground beef',
  '단무지': 'Pickled radish',
  '달걀노른자': 'Egg yolk',
  '닭가슴살': 'Chicken breast',
  '닭간': 'Chicken liver',
  '닭다리살': 'Chicken thigh',
  '당근': 'Carrot',
  '당면': 'Glass noodles',
  '대파': 'Green onion',
  '디종머스타드': 'Dijon mustard',
  '돈까스소스': 'Tonkatsu sauce',
  '돼지고기 등심': 'Pork loin',
  '돼지고기 목살': 'Pork collar',
  '돼지고기 안심': 'Pork tenderloin',
  '돼지고기 앞다리살': 'Pork shoulder',
  '돼지등뼈': 'Pork spine bones',
  '된장': 'Doenjang',
  '두반장': 'Doubanjiang',
  '두부': 'Tofu',
  '들깻가루': 'Perilla seed powder',
  '떡': 'Rice cake',
  '라면': 'Instant ramyeon',
  '라면사리': 'Instant ramyeon noodles',
  '라면스프': 'Ramyeon seasoning packet',
  '라자냐면': 'Lasagna noodles',
  '레드와인': 'Red wine',
  '로메인상추': 'Romaine lettuce',
  '로즈마리': 'Rosemary',
  '뇨끼': 'Potato gnocchi',
  '마늘': 'Garlic',
  '마요네즈': 'Mayonnaise',
  '만두': 'Dumplings (mandu)',
  '메밀면': 'Buckwheat noodles (soba)',
  '메이플시럽': 'Maple syrup',
  '명란젓': 'Salted pollock roe (myeongnan)',
  '멸치육수': 'Anchovy broth',
  '모짜렐라 치즈': 'Mozzarella cheese',
  '목이버섯': 'Wood ear mushroom',
  '무': 'Radish',
  '물엿': 'Corn syrup',
  '미림': 'Mirin',
  '미역': 'Miyeok (seaweed)',
  '바닐라에센스': 'Vanilla extract',
  '바질페스토': 'Basil pesto',
  '발사믹글레이즈': 'Balsamic glaze',
  '방울토마토': 'Cherry tomatoes',
  '밀가루': 'Flour',
  '바게트빵': 'Baguette',
  '바지락': 'Manila clams',
  '바질': 'Basil',
  '밥': 'Cooked rice',
  '버터': 'Butter',
  '베이컨': 'Bacon',
  '블랙올리브': 'Black olives',
  '비프육수': 'Beef stock',
  '부침가루': 'Pancake mix',
  '북어채': 'Dried pollock shreds',
  '숙주': 'Mung bean sprouts',
  '아보카도': 'Avocado',
  '연어': 'Salmon (sashimi-grade)',
  '연유': 'Condensed milk',
  '우스터소스': 'Worcestershire sauce',
  '조미김': 'Seasoned seaweed snack',
  '캔참치': 'Canned tuna',
  '토마토페이스트': 'Tomato paste',
  '튀김가루': 'Frying batter mix',
  '트러플오일': 'Truffle oil',
  '치킨육수': 'Chicken stock',
  '혼다시': 'Hondashi (bonito soup stock)',
  '화이트와인': 'White wine',
  '또르띠아': 'Tortilla',
  '빵가루': 'Breadcrumbs',
  '삼겹살': 'Pork belly',
  '새우': 'Shrimp',
  '새우젓': 'Salted shrimp (saeujeot)',
  '새우튀김': 'Fried shrimp (ebi fry)',
  '생강': 'Ginger',
  '생크림': 'Heavy cream',
  '설탕': 'Sugar',
  '소고기 갈비': 'Beef short rib',
  '소고기 등심': 'Beef sirloin',
  '소고기 양지': 'Beef brisket',
  '소금': 'Salt',
  '소면': 'Thin wheat noodles (somyeon)',
  '소시지': 'Sausage',
  '순두부': 'Soft tofu',
  '스파게티면': 'Spaghetti',
  '슬라이스치즈': 'Sliced cheese',
  '시금치': 'Spinach',
  '시나몬가루': 'Cinnamon powder',
  '식빵': 'Sliced bread',
  '식용유': 'Cooking oil',
  '식초': 'Vinegar',
  '쌀': 'Rice',
  '쌈장': 'Ssamjang',
  '애호박': 'Zucchini',
  '양배추': 'Cabbage',
  '양송이버섯': 'Button mushroom',
  '양파': 'Onion',
  '어묵': 'Fish cake',
  '오이': 'Cucumber',
  '오징어': 'Squid',
  '올리브유': 'Olive oil',
  '우거지': 'Dried radish greens',
  '우동면': 'Udon noodles',
  '우유': 'Milk',
  '월계수잎': 'Bay leaf',
  '유부': 'Fried tofu pouch',
  '전분가루': 'Starch',
  '조개살': 'Clam meat',
  '중화면': 'Chinese-style noodles',
  '진미채': 'Dried shredded squid',
  '짜장라면': 'Instant jjajang ramyeon',
  '짜파게티': 'Chapagetti noodles',
  '참기름': 'Sesame oil',
  '참치액': 'Tuna seasoning sauce (chamchi-aek)',
  '청양고추': 'Cheongyang chili pepper',
  '춘장': 'Chunjang (black bean paste)',
  '카레가루': 'Curry powder',
  '케첩': 'Ketchup',
  '콩나물': 'Soybean sprouts',
  '토마토': 'Tomato',
  '토마토소스': 'Tomato sauce',
  '통깨': 'Sesame seeds',
  '통후추': 'Whole peppercorns',
  '파르메산 치즈': 'Parmesan cheese',
  '파슬리': 'Parsley',
  '팬케이크가루': 'Pancake mix',
  '팽이버섯': 'Enoki mushroom',
  '페페론치노': 'Dried chili pepper',
  '표고버섯': 'Shiitake mushroom',
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
  '줄기': 'sprig',
  '조각': 'slice',
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

/// 냉장고 재료의 "단위" 입력란은 수량과 분리된 독립 필드라, localizedQuantity처럼
/// 개수 단위(개/마리)를 생략해버리면 필드가 텅 비어 보인다. 그래서 실제 단위 텍스트(ea 등)로 보여준다.
const _fridgeUnitDictionary = <String, String>{
  '단': 'bunch',
  '개': 'ea',
  '마리': 'ea',
  '포기': 'head',
  '봉': 'pack',
  '봉지': 'pack',
  '병': 'bottle',
  '줄기': 'stalk',
  '팩': 'pack',
  '줄': 'pack',
  '장': 'sheet',
  '모': 'block',
  '조각': 'slice',
  '컵': 'cup',
  '공기': 'bowl',
  '큰술': 'tbsp',
  '작은술': 'tsp',
  '꼬집': 'pinch',
};

/// 영문 단위 입력란을 다시 저장용 한글 단위로 되돌리기 위한 역방향 사전.
/// 여러 한글 단위가 같은 영문으로 매핑되는 경우(봉/봉지/줄→pack 등) 카탈로그에서 실제로
/// 쓰이는 대표 단어 하나만 남긴다 — 완벽한 왕복은 아니지만 표시용이라 문제되지 않는다.
const _fridgeUnitReverseDictionary = <String, String>{
  'bunch': '단',
  'ea': '개',
  'head': '포기',
  'pack': '봉',
  'bottle': '병',
  'stalk': '줄기',
  'sheet': '장',
  'block': '모',
  'slice': '조각',
  'cup': '컵',
  'bowl': '공기',
  'tbsp': '큰술',
  'tsp': '작은술',
  'pinch': '꼬집',
};

/// 냉장고 재료 단위를 현재 언어에 맞게 보여준다(g/kg/ml/L은 이미 만국 공통 표기라 그대로 둔다).
String localizedFridgeUnit(String koUnit) {
  if (LocaleStore.instance.isKorean) return koUnit;
  return _fridgeUnitDictionary[koUnit] ?? koUnit;
}

/// 영문 모드에서 사용자가 "단위" 입력란에 입력한 텍스트를 저장용 한글 단위로 되돌린다.
/// 사전에 없는 값(직접 입력한 커스텀 단위)은 입력한 그대로 저장한다.
String canonicalFridgeUnit(String displayedUnit) {
  if (LocaleStore.instance.isKorean) return displayedUnit;
  return _fridgeUnitReverseDictionary[displayedUnit] ?? displayedUnit;
}

/// 냉장고 재료 카드의 "수량+단위" 표시(예: "1단" / "1 bunch")를 언어별로 만든다.
String localizedFridgeQuantityLabel(double quantity, String unit) {
  final isWhole = quantity == quantity.roundToDouble();
  final q = isWhole ? quantity.toInt().toString() : quantity.toString();
  if (LocaleStore.instance.isKorean) return '$q$unit';
  return '$q ${localizedFridgeUnit(unit)}';
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
