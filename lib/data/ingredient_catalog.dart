/// ingredients 테이블(재료 마스터)을 흉내낸 로컬 검색용 카탈로그
/// 실제로는 Supabase의 ingredients 테이블에서 검색해서 불러오도록 교체 예정
class IngredientCatalogEntry {
  final String name;
  final String category;
  final String unitDefault;
  final int? defaultShelfLifeDays;
  /// 위키미디어 커먼즈에서 실물 사진으로 검증해둔 URL. recipe_catalog.dart의 photoUrl과
  /// 동일하게 /thumb/.../960px- 축소본 경로를 쓴다 — 원본 풀사이즈 경로는 위키미디어가
  /// 429(Too many requests)로 막고 축소본을 쓰라고 안내한다.
  /// 로딩 중/실패 시엔 IngredientPhoto가 기존 그라데이션+이모지로 대체한다.
  final String photoUrl;

  const IngredientCatalogEntry({
    required this.name,
    required this.category,
    required this.unitDefault,
    required this.photoUrl,
    this.defaultShelfLifeDays,
  });
}

const ingredientCatalog = <IngredientCatalogEntry>[
  IngredientCatalogEntry(
    name: '대파',
    category: '채소',
    unitDefault: '단',
    defaultShelfLifeDays: 10,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Scallion.jpg/960px-Scallion.jpg',
  ),
  IngredientCatalogEntry(
    name: '양파',
    category: '채소',
    unitDefault: '개',
    defaultShelfLifeDays: 30,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Onions.jpg/960px-Onions.jpg',
  ),
  IngredientCatalogEntry(
    name: '애호박',
    category: '채소',
    unitDefault: '개',
    defaultShelfLifeDays: 7,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Courgette.jpg/960px-Courgette.jpg',
  ),
  IngredientCatalogEntry(
    name: '시금치',
    category: '채소',
    unitDefault: '단',
    defaultShelfLifeDays: 5,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Spinach_leaves.jpg/960px-Spinach_leaves.jpg',
  ),
  IngredientCatalogEntry(
    name: '마늘',
    category: '채소',
    unitDefault: 'g',
    defaultShelfLifeDays: 30,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/Garlic.jpg/960px-Garlic.jpg',
  ),
  IngredientCatalogEntry(
    name: '감자',
    category: '채소',
    unitDefault: '개',
    defaultShelfLifeDays: 21,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Potatoes.jpg/960px-Potatoes.jpg',
  ),
  IngredientCatalogEntry(
    name: '돼지고기 앞다리살',
    category: '육류',
    unitDefault: 'g',
    defaultShelfLifeDays: 4,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Schweinenacken-1.jpg/960px-Schweinenacken-1.jpg',
  ),
  IngredientCatalogEntry(
    name: '소고기 등심',
    category: '육류',
    unitDefault: 'g',
    defaultShelfLifeDays: 4,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/Hanger-steak-raw-MCB.jpg/960px-Hanger-steak-raw-MCB.jpg',
  ),
  IngredientCatalogEntry(
    name: '닭가슴살',
    category: '육류',
    unitDefault: 'g',
    defaultShelfLifeDays: 3,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/Raw_chicken_slices.jpg/960px-Raw_chicken_slices.jpg',
  ),
  IngredientCatalogEntry(
    name: '삼겹살',
    category: '육류',
    unitDefault: 'g',
    defaultShelfLifeDays: 4,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Schweinebauch-1.jpg/960px-Schweinebauch-1.jpg',
  ),
  IngredientCatalogEntry(
    name: '계란',
    category: '유제품',
    unitDefault: '개',
    defaultShelfLifeDays: 21,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Egg.jpg/960px-Egg.jpg',
  ),
  IngredientCatalogEntry(
    name: '우유',
    category: '유제품',
    unitDefault: 'ml',
    defaultShelfLifeDays: 7,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/3/38/Glass_of_milk.jpg/960px-Glass_of_milk.jpg',
  ),
  IngredientCatalogEntry(
    name: '슬라이스치즈',
    category: '유제품',
    unitDefault: '장',
    defaultShelfLifeDays: 30,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/2019-11-30_17_10_43_A_couple_of_individually_wrapped_Harris_Teeter_American_Cheese_singles_in_the_Dulles_section_of_Sterling%2C_Loudoun_County%2C_Virginia.jpg/960px-2019-11-30_17_10_43_A_couple_of_individually_wrapped_Harris_Teeter_American_Cheese_singles_in_the_Dulles_section_of_Sterling%2C_Loudoun_County%2C_Virginia.jpg',
  ),
  IngredientCatalogEntry(
    name: '버터',
    category: '유제품',
    unitDefault: 'g',
    defaultShelfLifeDays: 60,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Stick-of-butter-salted.jpg/960px-Stick-of-butter-salted.jpg',
  ),
  IngredientCatalogEntry(
    name: '고등어',
    category: '수산',
    unitDefault: '마리',
    defaultShelfLifeDays: 2,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Scomber_scombrus.jpg/960px-Scomber_scombrus.jpg',
  ),
  IngredientCatalogEntry(
    name: '새우',
    category: '수산',
    unitDefault: 'g',
    defaultShelfLifeDays: 2,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Prawns.jpg/960px-Prawns.jpg',
  ),
  IngredientCatalogEntry(
    name: '두부',
    category: '기타',
    unitDefault: '모',
    defaultShelfLifeDays: 5,
    photoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Tofu_natural.jpg/960px-Tofu_natural.jpg',
  ),
  IngredientCatalogEntry(
    name: '김치',
    category: '기타',
    unitDefault: 'g',
    defaultShelfLifeDays: 60,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Kimchi.jpg/960px-Kimchi.jpg',
  ),
  IngredientCatalogEntry(
    name: '김',
    category: '기타',
    unitDefault: '봉',
    defaultShelfLifeDays: 90,
    photoUrl: 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Nori.jpg/960px-Nori.jpg',
  ),
];
