import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';
import '../models/user_profile.dart';
import '../services/chef_points_store.dart';
import '../services/locale_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'profile_view_sheet.dart';

typedef _RankRow = ({
  UserProfile profile,
  int points,
  bool isKFoodMaster,
  bool isMe
});

/// 등급별 파스텔 그라데이션 — 게임 아이템 획득 느낌의 은은한 배지 색.
/// 다크 배경 위에서도 소형 액세서리 칩은 파스텔을 그대로 유지하는 게 더 잘 도드라진다
/// (My Menu 아이콘 타일과 같은 원칙) — 그래서 이 색상들은 다크 전환 대상에서 제외한다.
({List<Color> colors, Color text}) _tierGradient(String? tier) {
  switch (tier) {
    case '초급요리사':
      return (
        colors: [const Color(0xFFFFF0DE), const Color(0xFFFFE0C2)],
        text: const Color(0xFFB4690E)
      );
    case '중급요리사':
      return (
        colors: [const Color(0xFFE8EEF7), const Color(0xFFD5E0EF)],
        text: const Color(0xFF4A6285)
      );
    case 'Food Master':
      return (
        colors: [const Color(0xFFFFF6D9), const Color(0xFFFFEAAC)],
        text: const Color(0xFF9C7A11)
      );
    default: // 요리 새싹
      return (
        colors: [const Color(0xFFE9F9EF), const Color(0xFFD7F3E3)],
        text: const Color(0xFF2F8A5B)
      );
  }
}

const _gold = Color(0xFFFFB020);

/// 라이트 배경 위 카드 — 헤어라인 보더 + 드롭 섀도우로 구분한다.
/// 포디움처럼 시선이 먼저 가야 하는 카드는 glow: true로 골드 섀도우를 한층 더 키운다.
BoxDecoration _cardDeco(
    {double radius = AppSpacing.radiusMd, bool glow = false}) {
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.cardBorder, width: 1.2),
    boxShadow: glow
        ? [
            BoxShadow(
                color: _gold.withValues(alpha: 0.16),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 6))
          ]
        : cardDropShadow(),
  );
}

/// "랭킹" — 가입한 전체 사용자를 누적 포인트가 높은 순서로 보여준다.
/// 상단 1~3위는 명예의 전당(포디움), 내 순위는 하단 스티키 바로 항상 고정 노출.
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
        isKFoodMaster:
            (points?.kfood ?? 0) >= ChefPointsStore.kfoodMasterThreshold,
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
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            tr('랭킹', 'Ranking'),
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.ink),
          ),
          actions: const [
            Padding(
                padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
          ],
        ),
        body: FutureBuilder<List<_RankRow>>(
          future: _rowsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.green));
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FridgeMascot(size: 84),
                    const SizedBox(height: AppSpacing.md),
                    Text(tr('아직 가입한 사용자가 없어요', 'No one has signed up yet'),
                        style: const TextStyle(color: AppColors.inkSoft)),
                  ],
                ),
              );
            }
            final podiumCount = rows.length < 3 ? rows.length : 3;
            final rest = rows.skip(podiumCount).toList();
            final myIndex = rows.indexWhere((r) => r.isMe);

            // 스크롤 리스트 + 하단 스티키 "내 순위" 바를 Stack으로 겹친다
            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                            AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                        child:
                            _RankPodium(rows: rows.take(podiumCount).toList()),
                      ),
                    ),
                    SliverPadding(
                      // 하단 스티키 바에 가려지지 않도록 아래 여백을 넉넉히 준다
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _RankingRow(
                              row: rest[i], rank: podiumCount + i + 1),
                          childCount: rest.length,
                        ),
                      ),
                    ),
                  ],
                ),
                if (myIndex >= 0)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _MyStickyRankingBar(
                        row: rows[myIndex], rank: myIndex + 1),
                  ),
              ],
            );
          },
        ),
        bottomNavigationBar: const MainBottomNav(currentIndex: 4),
      ),
    );
  }
}

/// 4위 이하 리스트 행 — 화이트 카드 + 헤어라인 보더로 구분하는 플랫 스타일
class _RankingRow extends StatelessWidget {
  final _RankRow row;
  final int rank;
  const _RankingRow({required this.row, required this.rank});

  @override
  Widget build(BuildContext context) {
    final view = row.profile.toPublicView();
    final tier = ChefPointsStore.tierForPoints(row.points);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => showProfileView(context, row.profile),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 12),
          decoration: _cardDeco(),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: AppColors.ink,
                      letterSpacing: -0.5),
                ),
              ),
              const SizedBox(width: 8),
              ClipOval(
                child: Container(
                  width: 40,
                  height: 40,
                  color: AppColors.paperDeep,
                  child: view.photoPath == null
                      ? const Icon(Icons.person,
                          size: 18, color: AppColors.inkSoft)
                      : Image.file(File(view.photoPath!),
                          fit: BoxFit.cover, width: 40, height: 40),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            view.nickname,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: -0.2,
                                color: AppColors.ink),
                          ),
                        ),
                        if (row.isMe) ...[
                          const SizedBox(width: 4),
                          Text(tr('(나)', '(Me)'),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.green)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _TierChip(tier: tier, isKFoodMaster: row.isKFoodMaster),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr('${row.points}점', '${row.points} pts'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.green,
                    letterSpacing: -0.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 등급명을 파스텔 그라데이션 캡슐로 보여주는 배지
class _TierChip extends StatelessWidget {
  final String? tier;
  final bool isKFoodMaster;
  const _TierChip({required this.tier, required this.isKFoodMaster});

  @override
  Widget build(BuildContext context) {
    final style = _tierGradient(tier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: style.colors),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            trTag(tier ?? '요리 새싹'),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: style.text),
          ),
        ),
        if (isKFoodMaster) ...[
          const SizedBox(width: 4),
          const Text('🇰🇷', style: TextStyle(fontSize: 12)),
        ],
      ],
    );
  }
}

/// 스크롤과 무관하게 화면 하단에 항상 고정되는 "내 순위" 바
class _MyStickyRankingBar extends StatelessWidget {
  final _RankRow row;
  final int rank;
  const _MyStickyRankingBar({required this.row, required this.rank});

  @override
  Widget build(BuildContext context) {
    final view = row.profile.toPublicView();
    final tier = ChefPointsStore.tierForPoints(row.points);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.green, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            tr('내 순위', 'My Rank'),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft),
          ),
          const SizedBox(width: 10),
          Text(
            '$rank',
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppColors.green,
                letterSpacing: -0.5),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: Container(
              width: 34,
              height: 34,
              color: AppColors.greenSoft,
              child: view.photoPath == null
                  ? const Icon(Icons.person, size: 16, color: AppColors.green)
                  : Image.file(File(view.photoPath!),
                      fit: BoxFit.cover, width: 34, height: 34),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  view.nickname,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.2,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                _TierChip(tier: tier, isKFoodMaster: row.isKFoodMaster),
              ],
            ),
          ),
          Text(
            tr('${row.points}점', '${row.points} pts'),
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.green,
                letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }
}

/// 상위 3명 "명예의 전당" — 화이트 카드 위 파스텔 포디움, 1위는 왕관을 쓴다
class _RankPodium extends StatelessWidget {
  final List<_RankRow> rows;
  const _RankPodium({required this.rows});

  static const _heights = [96.0, 68.0, 52.0];
  static const _avatarSizes = [68.0, 52.0, 48.0];
  static const _standColors = [
    [Color(0xFFFFF3D6), Color(0xFFFFE7AE)], // 1위: 골드 파스텔
    [Color(0xFFEDF2F9), Color(0xFFDDE6F2)], // 2위: 실버 파스텔
    [Color(0xFFFDEEE2), Color(0xFFF9DFC9)], // 3위: 브론즈 파스텔
  ];

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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
      decoration: _cardDeco(radius: AppSpacing.radiusLg, glow: true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final i in order)
            if (i < rows.length)
              Expanded(
                child: _PodiumSpot(
                  row: rows[i],
                  rank: i + 1,
                  standHeight: _heights[i],
                  avatarSize: _avatarSizes[i],
                  standColors: _standColors[i],
                ),
              ),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final _RankRow row;
  final int rank;
  final double standHeight;
  final double avatarSize;
  final List<Color> standColors;

  const _PodiumSpot({
    required this.row,
    required this.rank,
    required this.standHeight,
    required this.avatarSize,
    required this.standColors,
  });

  @override
  Widget build(BuildContext context) {
    final view = row.profile.toPublicView();
    final tier = ChefPointsStore.tierForPoints(row.points);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      onTap: () => showProfileView(context, row.profile),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1위만 왕관을 얹어 시각적 위계를 강조한다
          if (rank == 1) const Text('👑', style: TextStyle(fontSize: 24)),
          if (rank != 1) const SizedBox(height: 24),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: rank == 1 ? _gold : AppColors.cardBorder,
                width: rank == 1 ? 2.5 : 1.5,
              ),
              boxShadow: rank == 1
                  ? [
                      BoxShadow(
                          color: _gold.withValues(alpha: 0.3), blurRadius: 12)
                    ]
                  : null,
            ),
            child: ClipOval(
              child: Container(
                width: avatarSize,
                height: avatarSize,
                color: AppColors.paperDeep,
                child: view.photoPath == null
                    ? Icon(Icons.person,
                        size: avatarSize * 0.5, color: AppColors.inkSoft)
                    : Image.file(File(view.photoPath!),
                        fit: BoxFit.cover,
                        width: avatarSize,
                        height: avatarSize),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            view.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: -0.2),
          ),
          const SizedBox(height: 2),
          _TierChip(tier: tier, isKFoodMaster: row.isKFoodMaster),
          const SizedBox(height: 2),
          Text(
            tr('${row.points}점', '${row.points} pts'),
            style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            height: standHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: standColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusSm)),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: rank == 1 ? 30 : 22,
                fontWeight: FontWeight.w900,
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
