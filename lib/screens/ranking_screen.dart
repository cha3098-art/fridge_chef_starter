import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/user_profile.dart';
import '../services/chef_points_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/chef_badge.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'profile_view_sheet.dart';

/// 실제 서버가 없어 다른 사용자 데이터는 데모용 목업이다 — 랭킹 화면 시연을 위한 값
const _mockPoints = <String, int>{
  'chef_kim': 46,
  'foodlover88': 62,
  'jenny_cook': 12,
  'minsu_chef': 33,
};
const _mockKFoodMaster = <String>{'foodlover88'};

typedef _RankRow = ({UserProfile profile, int points, bool isKFoodMaster, bool isMe});

/// "랭킹" — 누적 포인트가 높은 순서로 사용자를 보여준다 (데모용 목업 사용자 포함)
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  List<_RankRow> _buildRows() {
    final rows = <_RankRow>[
      for (final profile in ProfileStore.mockProfiles)
        (
          profile: profile,
          points: _mockPoints[profile.id] ?? 0,
          isKFoodMaster: _mockKFoodMaster.contains(profile.id),
          isMe: false,
        ),
    ];
    final me = ProfileStore.instance.currentProfile;
    if (me != null) {
      rows.add((
        profile: me,
        points: ChefPointsStore.instance.generalPoints,
        isKFoodMaster: ChefPointsStore.instance.isKFoodMaster,
        isMe: true,
      ));
    }
    rows.sort((a, b) => b.points.compareTo(a.points));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text(tr('랭킹', 'Ranking')),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final row = rows[index];
          final view = row.profile.toPublicView();
          final tier = ChefPointsStore.tierForPoints(row.points);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showProfileView(context, row.profile),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: row.isMe ? AppColors.greenSoft : const Color(0xFFFFFFFF),
                border: Border.all(color: row.isMe ? AppColors.green : AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.inkSoft),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipOval(
                    child: Container(
                      width: 40,
                      height: 40,
                      color: AppColors.paperDeep,
                      child: view.photoPath == null
                          ? const Icon(Icons.person, size: 18, color: AppColors.inkSoft)
                          : Image.file(File(view.photoPath!), fit: BoxFit.cover, width: 40, height: 40),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(view.nickname, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            if (row.isMe) ...[
                              const SizedBox(width: 4),
                              Text(tr('(나)', '(Me)'), style: const TextStyle(fontSize: 11, color: AppColors.green)),
                            ],
                          ],
                        ),
                        Text(
                          '@${view.id} · ${trTag(view.gender)} · ${view.nationality}',
                          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ChefBadge(
                    generalTier: tier,
                    isKFoodMaster: row.isKFoodMaster,
                    showLabel: false,
                    medalSize: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('${row.points}점', '${row.points} pts'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 4),
    );
  }
}
