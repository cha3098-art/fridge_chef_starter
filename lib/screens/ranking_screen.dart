import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';
import '../models/user_profile.dart';
import '../services/chef_points_store.dart';
import '../services/locale_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/chef_badge.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'profile_view_sheet.dart';

typedef _RankRow = ({UserProfile profile, int points, bool isKFoodMaster, bool isMe});

/// "랭킹" — 가입한 전체 사용자를 누적 포인트가 높은 순서로 보여준다
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late final Future<List<_RankRow>> _rowsFuture = _loadRows();

  Future<List<_RankRow>> _loadRows() async {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final profiles = await ProfileStore.instance.fetchAll();
    final pointsByUser = await ChefPointsStore.fetchAllUserPoints();
    final rows = profiles.map((profile) {
      final points = pointsByUser[profile.id];
      return (
        profile: profile,
        points: points?.general ?? 0,
        isKFoodMaster: (points?.kfood ?? 0) >= ChefPointsStore.kfoodMasterThreshold,
        isMe: profile.id == myUid,
      );
    }).toList();
    rows.sort((a, b) => b.points.compareTo(a.points));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          tr('랭킹', 'Ranking'),
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
        ],
      ),
      body: FutureBuilder<List<_RankRow>>(
        future: _rowsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FridgeMascot(size: 84),
                  const SizedBox(height: AppSpacing.md),
                  Text(tr('아직 가입한 사용자가 없어요', 'No one has signed up yet'), style: const TextStyle(color: AppColors.inkSoft)),
                ],
              ),
            );
          }
          final podiumCount = rows.length < 3 ? rows.length : 3;
          final rest = rows.skip(podiumCount).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
            children: [
              _RankPodium(rows: rows.take(podiumCount).toList()),
              const SizedBox(height: AppSpacing.md),
              ...List.generate(rest.length, (i) {
                final index = podiumCount + i;
                final row = rest[i];
                final view = row.profile.toPublicView();
                final tier = ChefPointsStore.tierForPoints(row.points);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => showProfileView(context, row.profile),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: row.isMe ? AppColors.greenSoft : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: row.isMe ? AppColors.green : const Color(0xFFF1F5F9),
                          width: row.isMe ? 1.5 : 1,
                        ),
                        boxShadow: row.isMe
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF1E293B).withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                                    Text(
                                      view.nickname,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
                                    ),
                                    if (row.isMe) ...[
                                      const SizedBox(width: 4),
                                      Text(tr('(나)', '(Me)'), style: const TextStyle(fontSize: 11, color: AppColors.green)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${view.username} · ${trTag(view.gender)} · ${view.nationality}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.4),
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
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.green, letterSpacing: -0.1),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      bottomNavigationBar: MainBottomNav(currentIndex: 4),
      ),
    );
  }
}

/// 상위 3명을 배달앱 이벤트/리더보드에서 흔한 시상대(포디움) 스타일로 보여준다
class _RankPodium extends StatelessWidget {
  final List<_RankRow> rows;
  const _RankPodium({required this.rows});

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _heights = [92.0, 72.0, 56.0];
  static const _avatarSizes = [64.0, 52.0, 48.0];

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    // 시각적으로는 2등-1등-3등 순서로 배치한다
    final order = rows.length == 1
        ? [0]
        : rows.length == 2
            ? [1, 0]
            : [1, 0, 2];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.green, AppColors.greenDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final i in order)
            if (i < rows.length)
              Expanded(
                child: _PodiumSpot(
                  row: rows[i],
                  medal: _medals[i],
                  standHeight: _heights[i],
                  avatarSize: _avatarSizes[i],
                ),
              ),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final _RankRow row;
  final String medal;
  final double standHeight;
  final double avatarSize;

  const _PodiumSpot({
    required this.row,
    required this.medal,
    required this.standHeight,
    required this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    final view = row.profile.toPublicView();
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => showProfileView(context, row.profile),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medal, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          ClipOval(
            child: Container(
              width: avatarSize,
              height: avatarSize,
              color: Colors.white.withValues(alpha: 0.25),
              child: view.photoPath == null
                  ? Icon(Icons.person, size: avatarSize * 0.5, color: Colors.white)
                  : Image.file(File(view.photoPath!), fit: BoxFit.cover, width: avatarSize, height: avatarSize),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            view.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: -0.2),
          ),
          Text(
            tr('${row.points}점', '${row.points} pts'),
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            height: standHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSm)),
            ),
          ),
        ],
      ),
    );
  }
}
