enum DdayLevel { ok, warn, bad }

/// user_ingredients 테이블에 대응하는 냉장고 재료 모델
class FridgeItem {
  final String name;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final String category;

  const FridgeItem({
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
    if (d == null) return '기한없음';
    if (d < 0) return '만료';
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
