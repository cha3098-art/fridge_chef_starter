import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 메인 대시보드의 4대 분류 카드, 그리고 요리하기/푸드대결/소통공간 허브 화면의 2분할
/// 서브 카드가 함께 쓰는 큰 아이콘+제목+부제 카드. 대시보드에서는 4개가 2x2로,
/// 허브 화면에서는 2개가 세로로 나란히 배치된다.
class HubCategoryCard extends StatelessWidget {
  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HubCategoryCard({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: cardDropShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(iconAsset, width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.inkSoft, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
