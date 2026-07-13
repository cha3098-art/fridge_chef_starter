import 'package:flutter/material.dart';

/// 실제 사진 대신 쓰는 스타일리시한 플레이스홀더용 색상/이모지 매핑
/// 나중에 실제 사진(Supabase Storage의 image_url 등)으로 교체할 때는
/// 이 파일 대신 Image.network(url) 등으로 바꾸면 된다.

const _cuisineGradients = <String, List<Color>>{
  '한식': [Color(0xFFF3A26A), Color(0xFFE0673F)],
  '중식': [Color(0xFFE86B5C), Color(0xFFB8342A)],
  '양식': [Color(0xFF7FAE8C), Color(0xFF4C7A5C)],
  '분식': [Color(0xFFE8637F), Color(0xFFC23A57)],
};

const _defaultCuisineGradient = [Color(0xFFCBB994), Color(0xFF9C8459)];

List<Color> cuisineGradient(String cuisineType) =>
    _cuisineGradients[cuisineType] ?? _defaultCuisineGradient;

const _categoryGradients = <String, List<Color>>{
  '채소': [Color(0xFF9CC08B), Color(0xFF5E8F52)],
  '육류': [Color(0xFFE0937E), Color(0xFFB65C46)],
  '유제품': [Color(0xFFF0D48A), Color(0xFFCFA84C)],
  '수산': [Color(0xFF7FB8C4), Color(0xFF3F7E90)],
  '기타': [Color(0xFFCBB994), Color(0xFF9C8459)],
};

const _defaultCategoryGradient = [Color(0xFFCBB994), Color(0xFF9C8459)];

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

/// 재료 목록/카드에서 재사용하는 작은 원형 그라데이션 아바타
class IngredientAvatar extends StatelessWidget {
  final String name;
  final String category;
  final double size;

  const IngredientAvatar({
    super.key,
    required this.name,
    this.category = '기타',
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: categoryGradient(category),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        emojiForIngredient(name, category: category),
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}

/// LoremFlickr(키워드 기반 무료 CC 사진 서비스)에서 실제 음식 사진을 불러오고,
/// 로딩 중이거나 네트워크 실패 시에는 그라데이션+이모지 플레이스홀더로 대신 보여준다.
class RecipePhoto extends StatelessWidget {
  final String photoQuery;
  final String emoji;
  final String cuisineType;
  final double width;
  final double height;
  final int photoWidth;
  final int photoHeight;
  final BorderRadius borderRadius;
  final double emojiSize;

  const RecipePhoto({
    super.key,
    required this.photoQuery,
    required this.emoji,
    required this.cuisineType,
    required this.width,
    required this.height,
    this.photoWidth = 800,
    this.photoHeight = 480,
    this.borderRadius = BorderRadius.zero,
    this.emojiSize = 56,
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
    // lock 값으로 같은 요리는 항상 같은 사진을 받아오도록 고정한다
    final lock = photoQuery.hashCode.abs() % 1000;
    final url = 'https://loremflickr.com/$photoWidth/$photoHeight/$photoQuery?lock=$lock';
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : _placeholder(),
        errorBuilder: (context, error, stack) => _placeholder(),
      ),
    );
  }
}
