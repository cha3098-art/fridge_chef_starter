import '../models/ingredient_swap.dart';

/// ingredient_swaps 테이블 기본 시딩 데이터 — supabase_schema.sql의 동일 insert 블록과
/// 동일하게 유지한다 (IngredientSwapStore.seedDefaultsIfNeeded가 앱 실행 시 이 목록으로
/// 테이블이 비어있으면 채워 넣는다). 전부 돈 안 드는 흔한 조미료/냉장고 재료 대체 룰.
const ingredientSwapCatalog = <IngredientSwap>[
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
  IngredientSwap(
    originalIngredient: '맛술',
    substituteIngredient: '청주(또는 소주) 1큰술 + 설탕 약간',
    category: '조미료',
    tip: '잡내 제거와 은은한 단맛을 동시에 잡아줘요.',
  ),
  IngredientSwap(
    originalIngredient: '두반장',
    substituteIngredient: '고추장 1큰술 + 다진마늘 약간',
    category: '조미료',
    tip: '매콤함은 비슷하지만 발효 향은 덜해요.',
  ),
  IngredientSwap(
    originalIngredient: '쯔유',
    substituteIngredient: '간장 1큰술 + 맛술 1큰술 + 설탕 0.5큰술 + 물 2큰술',
    category: '조미료',
    tip: '일본식 국물 베이스를 집간장으로 바로 만들 수 있어요.',
  ),
  IngredientSwap(
    originalIngredient: '생크림',
    substituteIngredient: '우유 3큰술 + 버터 1큰술',
    category: '유제품',
    tip: '약불에서 버터를 녹여 섞으면 꾸덕한 질감이 비슷해져요.',
  ),
  IngredientSwap(
    originalIngredient: '마요네즈',
    substituteIngredient: '플레인 요거트 + 식초 약간',
    category: '조미료',
    tip: '더 산뜻한 맛이 되니 새콤한 요리에 잘 어울려요.',
  ),
  IngredientSwap(
    originalIngredient: '청주',
    substituteIngredient: '맛술 또는 소주 + 설탕 약간',
    category: '조미료',
    tip: '잡내 제거 용도라면 소주로도 충분히 대체돼요.',
  ),
  IngredientSwap(
    originalIngredient: '다진마늘',
    substituteIngredient: '마늘가루 1/3작은술',
    category: '채소',
    tip: '생마늘보다 향이 순해서 조금 더 넣어도 좋아요.',
  ),
  IngredientSwap(
    originalIngredient: '카레가루',
    substituteIngredient: '생략 후 설탕 약간 추가',
    category: '조미료',
    tip: '색과 향은 빠지지만 단짠 밸런스는 유지할 수 있어요.',
  ),
  IngredientSwap(
    originalIngredient: '참치액',
    substituteIngredient: '멸치액젓 또는 국간장 1작은술',
    category: '조미료',
    tip: '감칠맛 나는 액젓류라면 뭐든 비슷하게 대체돼요.',
  ),
  IngredientSwap(
    originalIngredient: '전분물',
    substituteIngredient: '밀가루 + 물 동량',
    category: '기타',
    tip: '점도는 비슷하지만 완성 후 살짝 더 뿌옇게 보일 수 있어요.',
  ),
  IngredientSwap(
    originalIngredient: '페페론치노',
    substituteIngredient: '청양고추 또는 고춧가루 약간',
    category: '채소',
    tip: '매운맛 정도만 취향껏 조절하면 돼요.',
  ),
  IngredientSwap(
    originalIngredient: '바질페스토',
    substituteIngredient: '다진마늘 + 올리브유 + 파마산치즈(생략 가능)',
    category: '조미료',
    tip: '바질이 없다면 마늘 향 오일만으로도 심플하게 즐길 수 있어요.',
  ),
  IngredientSwap(
    originalIngredient: '초고추장',
    substituteIngredient: '고추장 1큰술 + 식초 1작은술 + 설탕 1작은술',
    category: '조미료',
    tip: '새콤달콤한 비율은 입맛에 맞게 가감하세요.',
  ),
  IngredientSwap(
    originalIngredient: '설탕',
    substituteIngredient: '올리고당 또는 물엿 동량',
    category: '조미료',
    tip: '단맛은 비슷하되 윤기가 더 살아나요.',
  ),
];
