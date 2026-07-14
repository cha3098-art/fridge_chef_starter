import 'package:flutter/material.dart';

/// 실제 사진을 불러오기 전/실패했을 때 쓰는 플레이스홀더용 색상/이모지 매핑.
/// 어린아이 그림처럼 보이지 않도록 채도를 낮춘 톤 온 톤 그라데이션을 쓴다.

const _cuisineGradients = <String, List<Color>>{
  '한식': [Color(0xFFE4A579), Color(0xFFC97B54)],
  '중식': [Color(0xFFD98A78), Color(0xFFB25C4C)],
  '양식': [Color(0xFF8FAD8F), Color(0xFF5E7D5E)],
  '분식': [Color(0xFFD98297), Color(0xFFAD5670)],
};

const _defaultCuisineGradient = [Color(0xFFC7B896), Color(0xFF9C8C6B)];

List<Color> cuisineGradient(String cuisineType) =>
    _cuisineGradients[cuisineType] ?? _defaultCuisineGradient;

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
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        photoUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null ? child : _placeholder(),
        errorBuilder: (context, error, stack) => _placeholder(),
      ),
    );
  }
}
