import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/chef_points_store.dart';
import '../theme/app_theme.dart';
import 'chef_badge.dart';

/// 전체 화면 상단에 붙는 요리 등급 배지 — ChefPointsStore를 구독해서 실시간으로 갱신된다.
/// 일반 등급(초급/중급/Food Master)과 K-Food 마스터는 서로 별개로 표시된다.
class ChefTierBadge extends StatelessWidget {
  const ChefTierBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChefPointsStore.instance,
      builder: (context, _) {
        final store = ChefPointsStore.instance;
        final tier = store.generalTier;
        final medal = medalEmojiForGeneralTier(tier);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(medal ?? '🍳', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    tier != null ? trTag(tier) : '${store.generalPoints}P',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green),
                  ),
                ],
              ),
            ),
            if (store.isKFoodMaster) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE3E3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '🇰🇷 K-FOOD Master',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFC23A3A)),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
