import '../l10n/tr.dart';

enum DdayLevel { ok, warn, bad }

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

  const FridgeItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    this.category = '기타',
  });

  String get quantityLabel {
    final isWhole = quantity == quantity.roundToDouble();
    final q = isWhole ? quantity.toInt().toString() : quantity.toString();
    return '$q$unit';
  }

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
    if (d <= 3) return DdayLevel.warn;
    return DdayLevel.ok;
  }
}
