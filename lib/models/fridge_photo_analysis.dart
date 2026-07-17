import 'fridge_item.dart';

/// analyze-fridge-photo Edge Function이 반환하는, 우리 ingredients 카탈로그와
/// 실제로 이름이 일치하는 재료 1건 — FridgeItem으로 변환하기 전 단계의 원시 인식 결과다.
///
/// OcrParserService(영수증 스캔)와 같은 원칙: AI가 카탈로그에 없는 이름을 인식해도
/// 그 항목은 여기 담기지 않는다(FridgeStore.addItems가 카탈로그에 없는 이름은 조용히
/// 등록을 스킵하기 때문) — 화면에는 실제로 등록 가능한 매칭 결과만 체크박스로 보여준다.
class RecognizedIngredient {
  /// ingredients 테이블의 uuid — 등록 자체에는 쓰이지 않지만 추후 재료 상세 조회 등에 쓸 수 있다.
  final String id;
  final String name;
  final String category;
  final String unitDefault;
  final int? defaultShelfLifeDays;

  const RecognizedIngredient({
    required this.id,
    required this.name,
    required this.category,
    required this.unitDefault,
    this.defaultShelfLifeDays,
  });

  factory RecognizedIngredient.fromJson(Map<String, dynamic> json) {
    return RecognizedIngredient(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? '기타',
      unitDefault: json['unitDefault'] as String? ?? '개',
      defaultShelfLifeDays: json['defaultShelfLifeDays'] as int?,
    );
  }

  /// 사용자가 체크박스에서 선택한 항목을 실제 냉장고 등록용 FridgeItem으로 변환한다.
  /// 수량은 검색 탭과 동일하게 기본 1, 유통기한은 카탈로그의 기본 보관일수를 그대로 쓴다
  /// (영수증 스캔 탭과 동일한 등록 전 화면에서 사용자가 수정할 수 있다).
  FridgeItem toFridgeItem() {
    return FridgeItem(
      name: name,
      quantity: 1,
      unit: unitDefault,
      category: category,
      expiryDate: defaultShelfLifeDays != null
          ? DateTime.now().add(Duration(days: defaultShelfLifeDays!))
          : null,
    );
  }
}

/// analyze-fridge-photo 응답 전체 — 매칭된 재료 목록과, AI가 원래 인식한 한글 이름
/// 원본 목록을 함께 담는다. recognizedRaw는 matched에 없는 이름(카탈로그 밖 재료)을
/// "이런 것도 찍혔는데 등록은 안 돼요" 식으로 투명하게 보여주고 싶을 때 화면에서 쓸 수 있다.
class FridgePhotoAnalysis {
  final List<String> recognizedRaw;
  final List<RecognizedIngredient> matched;

  const FridgePhotoAnalysis(
      {required this.recognizedRaw, required this.matched});

  factory FridgePhotoAnalysis.fromJson(Map<String, dynamic> json) {
    return FridgePhotoAnalysis(
      recognizedRaw:
          (json['recognized'] as List<dynamic>? ?? const []).cast<String>(),
      matched: (json['matched'] as List<dynamic>? ?? const [])
          .map((e) => RecognizedIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
