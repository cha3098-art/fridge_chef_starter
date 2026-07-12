/// ingredients 테이블(재료 마스터)을 흉내낸 로컬 검색용 카탈로그
/// 실제로는 Supabase의 ingredients 테이블에서 검색해서 불러오도록 교체 예정
class IngredientCatalogEntry {
  final String name;
  final String category;
  final String unitDefault;
  final int? defaultShelfLifeDays;

  const IngredientCatalogEntry({
    required this.name,
    required this.category,
    required this.unitDefault,
    this.defaultShelfLifeDays,
  });
}

const ingredientCatalog = <IngredientCatalogEntry>[
  IngredientCatalogEntry(name: '대파', category: '채소', unitDefault: '단', defaultShelfLifeDays: 10),
  IngredientCatalogEntry(name: '양파', category: '채소', unitDefault: '개', defaultShelfLifeDays: 30),
  IngredientCatalogEntry(name: '애호박', category: '채소', unitDefault: '개', defaultShelfLifeDays: 7),
  IngredientCatalogEntry(name: '시금치', category: '채소', unitDefault: '단', defaultShelfLifeDays: 5),
  IngredientCatalogEntry(name: '마늘', category: '채소', unitDefault: 'g', defaultShelfLifeDays: 30),
  IngredientCatalogEntry(name: '감자', category: '채소', unitDefault: '개', defaultShelfLifeDays: 21),
  IngredientCatalogEntry(name: '돼지고기 앞다리살', category: '육류', unitDefault: 'g', defaultShelfLifeDays: 4),
  IngredientCatalogEntry(name: '소고기 등심', category: '육류', unitDefault: 'g', defaultShelfLifeDays: 4),
  IngredientCatalogEntry(name: '닭가슴살', category: '육류', unitDefault: 'g', defaultShelfLifeDays: 3),
  IngredientCatalogEntry(name: '삼겹살', category: '육류', unitDefault: 'g', defaultShelfLifeDays: 4),
  IngredientCatalogEntry(name: '계란', category: '유제품', unitDefault: '개', defaultShelfLifeDays: 21),
  IngredientCatalogEntry(name: '우유', category: '유제품', unitDefault: 'ml', defaultShelfLifeDays: 7),
  IngredientCatalogEntry(name: '슬라이스치즈', category: '유제품', unitDefault: '장', defaultShelfLifeDays: 30),
  IngredientCatalogEntry(name: '버터', category: '유제품', unitDefault: 'g', defaultShelfLifeDays: 60),
  IngredientCatalogEntry(name: '고등어', category: '수산', unitDefault: '마리', defaultShelfLifeDays: 2),
  IngredientCatalogEntry(name: '새우', category: '수산', unitDefault: 'g', defaultShelfLifeDays: 2),
  IngredientCatalogEntry(name: '두부', category: '기타', unitDefault: '모', defaultShelfLifeDays: 5),
  IngredientCatalogEntry(name: '김치', category: '기타', unitDefault: 'g', defaultShelfLifeDays: 60),
  IngredientCatalogEntry(name: '김', category: '기타', unitDefault: '봉', defaultShelfLifeDays: 90),
];
