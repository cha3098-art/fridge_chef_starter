import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/ingredient_catalog.dart';
import '../models/fridge_item.dart';

/// 영수증 사진에서 텍스트를 인식해 우리 재료 카탈로그와 매칭되는 항목만 골라낸다.
///
/// 카탈로그에 없는 이름으로 골라내면 FridgeStore.addItems()가 조용히 스킵해버리므로
/// (ingredients 테이블에 없는 재료는 등록 자체가 안 됨), 임의의 키워드 사전을 따로 두지 않고
/// 반드시 ingredientCatalog의 실제 항목 이름으로만 매칭한다.
class OcrParserService {
  OcrParserService._();
  static final OcrParserService instance = OcrParserService._();

  /// 영수증 이미지에서 인식된 텍스트 중 카탈로그와 매칭되는 재료를 FridgeItem 목록으로 반환한다.
  /// 수량/단위/유통기한은 카탈로그의 기본값을 그대로 쓰고, 등록 전 화면에서 사용자가 수정할 수 있다.
  Future<List<FridgeItem>> parseReceipt(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final result = await recognizer.processImage(InputImage.fromFile(imageFile));
      final normalizedText = result.text.replaceAll(RegExp(r'\s+'), '');

      final matched = <FridgeItem>[];
      for (final entry in ingredientCatalog) {
        if (!normalizedText.contains(entry.name)) continue;
        matched.add(FridgeItem(
          name: entry.name,
          quantity: 1,
          unit: entry.unitDefault,
          category: entry.category,
          expiryDate: entry.defaultShelfLifeDays != null
              ? DateTime.now().add(Duration(days: entry.defaultShelfLifeDays!))
              : null,
        ));
      }
      return matched;
    } finally {
      await recognizer.close();
    }
  }
}
