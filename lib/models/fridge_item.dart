import '../l10n/recipe_i18n.dart';
import '../l10n/tr.dart';

enum DdayLevel { ok, warn, bad }

/// 냉장고관리 화면의 저장 위치 — user_ingredients.storage_location과 1:1 대응
enum StorageLocation { fridge, freezer }

extension StorageLocationLabel on StorageLocation {
  String get dbValue => this == StorageLocation.fridge ? 'fridge' : 'freezer';
  String get label =>
      this == StorageLocation.fridge ? tr('냉장고', 'Fridge') : tr('냉동고', 'Freezer');

  static StorageLocation fromDbValue(String? value) =>
      value == 'freezer' ? StorageLocation.freezer : StorageLocation.fridge;
}

/// 냉장고관리 화면의 세부 분류 — ingredient_catalog.dart의 category(채소/육류/유제품/수산/기타)보다
/// 세분화된 목록. 카탈로그 category에서 합리적인 기본값을 매핑해주고, 사용자가 등록 시 직접 바꿀 수 있다.
const storageCategories = ['육류', '유제품', '야채', '생선', '밑반찬', '소스', '기타'];

String defaultStorageCategory(String catalogCategory) {
  switch (catalogCategory) {
    case '채소':
      return '야채';
    case '수산':
      return '생선';
    case '육류':
    case '유제품':
      return catalogCategory;
    default:
      return storageCategories.contains(catalogCategory) ? catalogCategory : '기타';
  }
}

/// defaultStorageCategory의 역방향 — 직접입력처럼 세부분류만 고르고 카탈로그
/// category를 안 받는 화면에서, ingredients 마스터 행에 넣을 category를 만든다.
String catalogCategoryForStorage(String storageCategory) {
  switch (storageCategory) {
    case '야채':
      return '채소';
    case '생선':
      return '수산';
    case '육류':
    case '유제품':
      return storageCategory;
    default:
      return '기타';
  }
}

/// user_ingredients 테이블에 대응하는 냉장고 재료 모델
class FridgeItem {
  /// user_ingredients.id — DB에서 불러온 항목만 값이 있고, 등록 화면에서
  /// 갓 만든(아직 insert 전) 항목은 null이다
  final String? id;
  final String name;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final String category;
  final StorageLocation storageLocation;
  final String storageCategory;

  FridgeItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.category = '기타',
    this.storageLocation = StorageLocation.fridge,
    String? storageCategory,
  }) : storageCategory = storageCategory ?? defaultStorageCategory(category);

  String get quantityLabel => localizedFridgeQuantityLabel(quantity, unit);

  int? get daysLeft {
    final expiry = expiryDate;
    if (expiry == null) return null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    return expiryDay.difference(todayDate).inDays;
  }

  String get ddayLabel {
    final d = daysLeft;
    if (d == null) return tr('기한없음', 'No expiry');
    if (d < 0) return tr('만료', 'Expired');
    if (d == 0) return 'D-day';
    return 'D-$d';
  }

  DdayLevel get ddayLevel {
    final d = daysLeft;
    if (d == null) return DdayLevel.ok;
    if (d < 0) return DdayLevel.bad;
    if (d <= 3) return DdayLevel.bad;
    if (d <= 7) return DdayLevel.warn;
    return DdayLevel.ok;
  }
}
