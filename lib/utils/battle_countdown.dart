import '../l10n/tr.dart';

/// 배틀 목록/상세 화면이 공유하는 "N일 N시간 남음" 스타일 카운트다운 포맷터.
String formatBattleCountdown(Duration remaining) {
  if (remaining.isNegative) return tr('곧 마감', 'Closing soon');
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  if (days >= 1) {
    return tr('$days일 $hours시간 남음', '${days}d ${hours}h left');
  }
  if (remaining.inHours >= 1) {
    return tr('$hours시간 $minutes분 남음', '${remaining.inHours}h ${minutes}m left');
  }
  return tr('$minutes분 남음', '${minutes}m left');
}
