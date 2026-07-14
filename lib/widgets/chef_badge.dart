import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// 일반 등급 → 메달 이모지 매핑 (초급=동, 중급=은, Food Master=금)
String? medalEmojiForGeneralTier(String? tier) {
  switch (tier) {
    case '초급요리사':
      return '🥉';
    case '중급요리사':
      return '🥈';
    case 'Food Master':
      return '🥇';
    default:
      return null;
  }
}

/// 등급 배지 — 메달 + (선택적으로) 아래에 작은 등급명 라벨.
/// K-FOOD 마스터는 별개 배지로 옆에 추가 표시된다.
/// 게시판처럼 공간이 좁은 곳에서는 showLabel:false로 라벨을 생략한다.
class ChefBadge extends StatelessWidget {
  final String? generalTier;
  final bool isKFoodMaster;
  final bool showLabel;
  final double medalSize;
  final Color labelColor;

  const ChefBadge({
    super.key,
    required this.generalTier,
    required this.isKFoodMaster,
    this.showLabel = true,
    this.medalSize = 22,
    this.labelColor = AppColors.inkSoft,
  });

  @override
  Widget build(BuildContext context) {
    final medal = medalEmojiForGeneralTier(generalTier);
    if (medal == null && !isKFoodMaster) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (medal != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(medal, style: TextStyle(fontSize: medalSize)),
              if (showLabel)
                Text(
                  trTag(generalTier!),
                  style: TextStyle(fontSize: 9, color: labelColor, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        if (isKFoodMaster) ...[
          if (medal != null) const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇰🇷', style: TextStyle(fontSize: medalSize)),
              if (showLabel)
                Text(
                  'K-FOOD Master',
                  style: TextStyle(fontSize: 9, color: labelColor, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
