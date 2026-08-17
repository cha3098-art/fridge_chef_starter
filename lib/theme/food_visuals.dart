import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 위키미디어 thumb URL의 요청 해상도를 실제 표시 크기(물리 픽셀)에 맞게 낮춘다.
/// 카탈로그에 박아둔 원본은 보통 960px인데, 74px짜리 목록 썸네일에 그걸 그대로
/// 받으면 대역폭도, 디코드 비용도 낭비된다. Wikimedia의 thumb 서버는 URL의
/// "NNNpx-" 부분만 바꾸면 그 폭으로 즉석에서 리사이즈해서 내려준다.
/// 이 패턴이 아닌 URL(향후 다른 CDN 등)은 원본 그대로 반환한다.
String resizedThumbUrl(String url, double physicalSize) {
  final match = RegExp(r'/(\d+)px-').firstMatch(url);
  if (match == null) return url;
  final target = physicalSize.clamp(100, 960).round();
  return url.replaceFirst(match.group(0)!, '/${target}px-');
}

/// `CachedNetworkImage`의 `memCacheWidth/Height`용 안전 변환 — 부모가 폭/높이를
/// `double.infinity`로 채워주는 흔한 패턴(RecipePhoto가 목록 카드에서 이렇게 쓰인다)을
/// 그대로 `.round()`하면 "Unsupported operation: Infinity or NaN toInt" 런타임 크래시가
/// 난다. 유한한 값일 때만 디코드 크기 힌트를 주고, 아니면 힌트를 생략한다(원본 그대로 디코드).
int? _safeCacheDim(double value) => value.isFinite ? value.round() : null;

/// 실제 사진을 불러오기 전/실패했을 때 쓰는 플레이스홀더용 색상/이모지 매핑.
/// 어린아이 그림처럼 보이지 않도록 채도를 낮춘 톤 온 톤 그라데이션을 쓴다.

const _cuisineGradients = <String, List<Color>>{
  '한식': [Color(0xFFE4A579), Color(0xFFC97B54)],
  '중식': [Color(0xFFD98A78), Color(0xFFB25C4C)],
  '양식': [Color(0xFF8FAD8F), Color(0xFF5E7D5E)],
  '분식': [Color(0xFFD98297), Color(0xFFAD5670)],
  '일식': [Color(0xFFE3B7A0), Color(0xFFB5806A)],
  '이탈리아식': [Color(0xFFC9A961), Color(0xFF8F7B3F)],
  '프랑스식': [Color(0xFFA9A5C9), Color(0xFF716B9E)],
};

const _defaultCuisineGradient = [Color(0xFFC7B896), Color(0xFF9C8C6B)];

List<Color> cuisineGradient(String cuisineType) =>
    _cuisineGradients[cuisineType] ?? _defaultCuisineGradient;

/// 요리자랑 글쓰기에서 고르는 테마 액자 프레임 이미지 — 요리 종류별 샘플 음식 일러스트가
/// 테두리에 둘려 있다. 총 7종을 제공한다.
const bragFrameCategories = <String>[
  '한식',
  '중식',
  '일식',
  '양식',
  '분식',
  '이탈리아식',
  '프랑스식',
];

// 원본은 JPG라 투명 배경이 없어서, 체커보드(불투명)를 실제 알파 투명으로 되돌린
// PNG 버전을 만들어 assets/frames/에 함께 저장해두고 그걸 참조한다.
const _bragFrameAssets = <String, String>{
  '한식': 'assets/frames/han-sik-frame.png',
  '중식': 'assets/frames/Joon-sik-frame.png',
  '일식': 'assets/frames/il-sik-frame.png',
  '양식': 'assets/frames/yang-sik-frame.png',
  '분식': 'assets/frames/bun-sik-frame.png',
  '이탈리아식': 'assets/frames/italy-frame.png',
  '프랑스식': 'assets/frames/france-frame.png',
};

String bragFrameAsset(String frameCategory) =>
    _bragFrameAssets[frameCategory] ?? _bragFrameAssets['한식']!;

const _categoryGradients = <String, List<Color>>{
  '채소': [Color(0xFFA3BE92), Color(0xFF74945F)],
  '육류': [Color(0xFFCC9284), Color(0xFF9F6659)],
  '유제품': [Color(0xFFDDBE84), Color(0xFFB4924F)],
  '수산': [Color(0xFF8CADB6), Color(0xFF5C818C)],
  '기타': [Color(0xFFC7B896), Color(0xFF9C8C6B)],
};

const _defaultCategoryGradient = [Color(0xFFC7B896), Color(0xFF9C8C6B)];

List<Color> categoryGradient(String category) =>
    _categoryGradients[category] ?? _defaultCategoryGradient;

const _ingredientEmoji = <String, String>{
  '대파': '🌱',
  '양파': '🧅',
  '애호박': '🥒',
  '시금치': '🥬',
  '마늘': '🧄',
  '감자': '🥔',
  '돼지고기 앞다리살': '🥩',
  '소고기 등심': '🥩',
  '닭가슴살': '🍗',
  '삼겹살': '🥓',
  '계란': '🥚',
  '우유': '🥛',
  '슬라이스치즈': '🧀',
  '버터': '🧈',
  '고등어': '🐟',
  '새우': '🍤',
  '두부': '🧊',
  '김치': '🌶️',
  '김': '🍙',
  '가지': '🍆',
  '간장': '🫙',
  '갈치': '🐟',
  '고구마': '🍠',
  '고사리': '🌿',
  '고추장': '🌶️',
  '고춧가루': '🌶️',
  '고형카레': '🍛',
  '국간장': '🫙',
  '굴소스': '🦪',
  '그뤼에르 치즈': '🧀',
  '낙지': '🐙',
  '너구리': '🍜',
  '다진 소고기': '🥩',
  '달걀노른자': '🥚',
  '닭간': '🍗',
  '닭다리살': '🍗',
  '당근': '🥕',
  '당면': '🍜',
  '돼지고기 등심': '🥩',
  '돼지고기 목살': '🥩',
  '돼지고기 안심': '🥩',
  '돼지등뼈': '🦴',
  '된장': '🫙',
  '떡': '🍡',
  '또르띠아': '🫓',
  '라면': '🍜',
  '라면사리': '🍜',
  '라자냐면': '🍝',
  '레드와인': '🍷',
  '레몬': '🍋',
  '로메인상추': '🥬',
  '로즈마리': '🌿',
  '만두': '🥟',
  '메밀면': '🍜',
  '메이플시럽': '🍯',
  '멸치육수': '🐟',
  '명란젓': '🐟',
  '모짜렐라 치즈': '🧀',
  '목이버섯': '🍄',
  '물엿': '🍯',
  '미림': '🍶',
  '미역': '🌿',
  '밀가루': '🌾',
  '바게트빵': '🥖',
  '바지락': '🐚',
  '바질': '🌿',
  '밥': '🍚',
  '방울토마토': '🍅',
  '베이컨': '🥓',
  '북어채': '🐟',
  '비프육수': '🍲',
  '빵가루': '🍞',
  '새우젓': '🍤',
  '새우튀김': '🍤',
  '생강': '🫚',
  '생크림': '🥛',
  '소고기 갈비': '🥩',
  '소고기 양지': '🥩',
  '소금': '🧂',
  '소면': '🍜',
  '소시지': '🌭',
  '숙주': '🌱',
  '순두부': '🧊',
  '스파게티면': '🍝',
  '식빵': '🍞',
  '식용유': '🫙',
  '쌀': '🌾',
  '아보카도': '🥑',
  '양배추': '🥬',
  '양송이버섯': '🍄',
  '어묵': '🍢',
  '연어': '🐟',
  '연유': '🥛',
  '오이': '🥒',
  '오징어': '🦑',
  '올리브유': '🫒',
  '우거지': '🥬',
  '우동면': '🍜',
  '월계수잎': '🌿',
  '조개살': '🐚',
  '조미김': '🍙',
  '중화면': '🍜',
  '진미채': '🦑',
  '짜장라면': '🍜',
  '짜파게티': '🍜',
  '참기름': '🫙',
  '참치액': '🐟',
  '청양고추': '🌶️',
  '치킨육수': '🍲',
  '카레가루': '🍛',
  '캔참치': '🥫',
  '케첩': '🍅',
  '콩나물': '🌱',
  '토마토': '🍅',
  '토마토소스': '🍅',
  '토마토페이스트': '🍅',
  '파르메산 치즈': '🧀',
  '파슬리': '🌿',
  '팬케이크가루': '🥞',
  '팽이버섯': '🍄',
  '페페론치노': '🌶️',
  '표고버섯': '🍄',
  '햄': '🍖',
  '화이트와인': '🍷',
};

const _categoryFallbackEmoji = <String, String>{
  '채소': '🥬',
  '육류': '🥩',
  '유제품': '🧀',
  '수산': '🐟',
  '기타': '🍽️',
};

String emojiForIngredient(String name, {String category = '기타'}) =>
    _ingredientEmoji[name] ?? _categoryFallbackEmoji[category] ?? '🍽️';

/// 카테고리 자체를 대표하는 이모지 (전체 카테고리 필터 아이콘 등에 사용)
String emojiForCategory(String category) => category == '전체'
    ? '🧺'
    : _categoryFallbackEmoji[category] ?? '🍽️';

/// 재료 목록/카드에서 재사용하는 작은 원형 그라데이션 아바타
class IngredientAvatar extends StatelessWidget {
  final String name;
  final String category;
  final double size;
  /// true면 카테고리 그라데이션의 진한 쪽 색으로 얇은 테두리 링을 더해준다 —
  /// 어두운 배경 위 리스트처럼 아바타 발색을 한 번 더 강조하고 싶을 때만 켠다.
  final bool showBorder;

  const IngredientAvatar({
    super.key,
    required this.name,
    this.category = '기타',
    this.size = 40,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = categoryGradient(category);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: showBorder ? Border.all(color: gradient.last.withValues(alpha: 0.6), width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        emojiForIngredient(name, category: category),
        style: TextStyle(fontSize: size * 0.42),
      ),
    );
  }
}

/// IngredientAvatar의 사진 버전 — 위키미디어 커먼즈에서 재료명으로 직접 검증해둔 실물 사진을
/// 원형으로 보여주고, 로딩 중이거나 네트워크 실패 시엔 기존 IngredientAvatar와 똑같은
/// 그라데이션+이모지로 자연스럽게 대체된다 (RecipePhoto와 동일한 패턴).
class IngredientPhoto extends StatelessWidget {
  final String photoUrl;
  final String name;
  final String category;
  final double size;
  final bool showBorder;

  const IngredientPhoto({
    super.key,
    required this.photoUrl,
    required this.name,
    this.category = '기타',
    this.size = 40,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = categoryGradient(category);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: gradient.last.withValues(alpha: 0.6), width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: CachedNetworkImage(
        imageUrl: resizedThumbUrl(
            photoUrl, size * MediaQuery.of(context).devicePixelRatio),
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth:
            _safeCacheDim(size * MediaQuery.of(context).devicePixelRatio),
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) =>
            IngredientAvatar(name: name, category: category, size: size),
        errorWidget: (context, url, error) =>
            IngredientAvatar(name: name, category: category, size: size),
      ),
    );
  }
}

/// 위키미디어 커먼즈에서 요리명으로 직접 검증해둔 실제 사진을 보여주고,
/// 로딩 중이거나 네트워크 실패 시에는 은은한 그라데이션+이모지 플레이스홀더로 대신한다.
class RecipePhoto extends StatelessWidget {
  final String photoUrl;
  final String emoji;
  final String cuisineType;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double emojiSize;

  const RecipePhoto({
    super.key,
    required this.photoUrl,
    required this.emoji,
    required this.cuisineType,
    required this.width,
    required this.height,
    this.borderRadius = BorderRadius.zero,
    this.emojiSize = 40,
  });

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cuisineGradient(cuisineType),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
      ),
      child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: resizedThumbUrl(photoUrl, width * dpr),
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: _safeCacheDim(width * dpr),
        memCacheHeight: _safeCacheDim(height * dpr),
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => _placeholder(),
        errorWidget: (context, url, error) => _placeholder(),
      ),
    );
  }
}
