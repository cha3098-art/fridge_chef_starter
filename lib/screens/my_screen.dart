import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/chef_points.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/chef_points_store.dart';
import '../services/locale_store.dart';
import '../services/profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/chef_badge.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'board_screen.dart';
import 'ranking_screen.dart';
import 'sign_up_screen.dart';

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return tr('방금 전', 'just now');
  if (diff.inHours < 1)
    return tr('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
  if (diff.inDays < 1) return tr('${diff.inHours}시간 전', '${diff.inHours}h ago');
  return tr('${diff.inDays}일 전', '${diff.inDays}d ago');
}

BoxDecoration _cardDeco({double radius = 16}) {
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.cardBorder, width: 1),
    boxShadow: cardDropShadow(),
  );
}

/// "마이" 탭 — 누적 포인트, 등급, 주간 미션, 포인트 받는 방법을 보여준다
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // 다른 사용자가 내 게시글에 좋아요를 눌러 포인트가 바뀌었을 수 있으니 방문할 때마다 새로고침한다
    ChefPointsStore.instance.loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: const LabeledBackButton(),
        leadingWidth: 96,
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 76,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/icon/icon_my.png',
                  width: 58, height: 58, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text(
              tr('마이', 'My'),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.ink),
            ),
          ],
        ),
        actions: [
          if (ProfileStore.instance.currentProfile != null)
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.inkSoft),
              tooltip: tr('로그아웃', 'Sign out'),
              onPressed: () => _confirmSignOut(context),
            ),
          const Padding(
              padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          ChefPointsStore.instance,
          ProfileStore.instance,
          LocaleStore.instance
        ]),
        builder: (context, _) {
          final store = ChefPointsStore.instance;
          final profile = ProfileStore.instance.currentProfile;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
            children: [
              _ProfileHeader(profile: profile),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MenuButton(
                      icon: Icons.emoji_events_outlined,
                      label: tr('랭킹', 'Ranking'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RankingScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MenuButton(
                      icon: Icons.forum_outlined,
                      label: tr('게시판', 'Board'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BoardScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _TierCard(
                icon: medalEmojiForGeneralTier(store.generalTier) ?? '🍳',
                title: trTag(store.generalTier ?? '요리 새싹'),
                points: store.generalPoints,
                pointsToNext: store.pointsToNextTier,
                nextLabel: _nextGeneralTierLabel(store.generalPoints),
                accent: AppColors.green,
              ),
              const SizedBox(height: 12),
              _TierCard(
                icon: '🇰🇷',
                title: trTag(
                    store.isKFoodMaster ? 'K-FOOD Master' : 'K-Food 도전 중'),
                points: store.kfoodPoints,
                pointsToNext: store.isKFoodMaster
                    ? null
                    : ChefPointsStore.kfoodMasterThreshold - store.kfoodPoints,
                nextLabel: trTag('K-FOOD 마스터'),
                accent: AppColors.carrot,
              ),
              const SizedBox(height: 20),
              _SectionTitle(tr('이번 주 미션', 'This Week\'s Mission')),
              const SizedBox(height: 10),
              _WeeklyMissionCard(store: store),
              const SizedBox(height: 20),
              _SectionTitle(tr('포인트 받는 방법', 'How to Earn Points')),
              const SizedBox(height: 10),
              const _HowToEarnList(),
              const SizedBox(height: 20),
              _SectionTitle(tr('최근 포인트 내역', 'Recent Points')),
              const SizedBox(height: 10),
              if (store.events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(tr('아직 받은 포인트가 없어요', 'No points earned yet'),
                        style: const TextStyle(color: AppColors.inkSoft)),
                  ),
                )
              else
                Container(
                  decoration: _cardDeco(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    children: store.events
                        .take(20)
                        .map((e) => _PointEventRow(event: e))
                        .toList(),
                  ),
                ),
              if (profile != null) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(tr('로그아웃', 'Sign out'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      extendBody: true,
      bottomNavigationBar: const MainBottomNav(currentIndex: 2),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('로그아웃 할까요?', 'Sign out?')),
        content: Text(tr('다시 로그인하면 정보는 그대로 남아있어요.',
            "You'll keep all your data — just sign back in anytime.")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('취소', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('로그아웃', 'Sign out'),
                style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (!context.mounted) return;
      // 마이 화면까지 쌓인 push 스택을 걷어내서 AuthGate가 다시 그려주는
      // 로그인 화면(루트 라우트)이 바로 보이게 한다 — 안 그러면 로그아웃 후에도
      // 지금 화면에 그대로 남아 있다가 뒤로가기를 눌러야만 로그인 화면이 나타난다.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  static String? _nextGeneralTierLabel(int points) {
    if (points < 30) return trTag('초급요리사');
    if (points < 40) return trTag('중급요리사');
    if (points < 50) return trTag('Food Master');
    return null;
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: _cardDeco(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr('가입하고 랭킹·게시판·배지를 이용해보세요!',
                    'Sign up to use ranking, the board, and badges!'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              ),
              child: Text(tr('회원가입', 'Sign Up'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final p = profile!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDeco(radius: AppSpacing.radiusLg),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.6), width: 1.5),
              ),
              child: p.photoPath == null
                  ? const Icon(Icons.person, color: AppColors.green)
                  : Image.file(File(p.photoPath!),
                      fit: BoxFit.cover, width: 60, height: 60),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nickname,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('@${p.username}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: ChefPointsStore.instance,
            builder: (context, _) => ChefBadge(
              generalTier: ChefPointsStore.instance.generalTier,
              isKFoodMaster: ChefPointsStore.instance.isKFoodMaster,
              labelColor: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: _cardDeco(),
        child: Column(
          children: [
            Icon(icon, color: AppColors.green, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.ink,
          letterSpacing: -0.2),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String icon;
  final String title;
  final int points;
  final int? pointsToNext;
  final String? nextLabel;
  final Color accent;

  const _TierCard({
    required this.icon,
    required this.title,
    required this.points,
    required this.pointsToNext,
    required this.nextLabel,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.2),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tr('$points점', '$points pts'),
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
          if (pointsToNext != null && nextLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              tr('$nextLabel까지 $pointsToNext점 남았어요',
                  '$pointsToNext pts to $nextLabel'),
              style: const TextStyle(
                  color: AppColors.inkSoft, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyMissionCard extends StatelessWidget {
  final ChefPointsStore store;
  const _WeeklyMissionCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final cooks = store.cooksThisWeek;
    final invited = store.invitedThisWeek;
    final cookDone = cooks >= 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('7일간 요리 3회 + 초대함 이용 시 +1점',
                'Cook 3 times + use Inbox in 7 days → +1 pt'),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          _MissionRow(
              label: tr('요리 완성', 'Cook a recipe'),
              done: cookDone,
              detail: tr('$cooks/3회', '$cooks/3')),
          const SizedBox(height: 10),
          _MissionRow(
              label: tr('초대함 이용', 'Use Inbox'),
              done: invited,
              detail: invited ? tr('완료', 'Done') : tr('미완료', 'Not yet')),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final String label;
  final bool done;
  final String detail;
  const _MissionRow(
      {required this.label, required this.done, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: done ? AppColors.green : AppColors.inkSoft,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink)),
        const Spacer(),
        Text(detail,
            style: TextStyle(
                fontSize: 12,
                color: done ? AppColors.green : AppColors.inkSoft)),
      ],
    );
  }
}

class _HowToEarnList extends StatelessWidget {
  const _HowToEarnList();

  static const _rules = [
    (
      '🍳',
      '레시피 완성(자랑하기)',
      'Finish a recipe (brag)',
      '난이도 하 +1 · 중 +2 · 상 +3점',
      'Easy +1 · Medium +2 · Hard +3 pts'
    ),
    (
      '🇰🇷',
      'K-Food 레시피 완성',
      'Finish a K-Food recipe',
      '난이도별 점수가 K-Food 점수에도 적립',
      'Also counts toward K-Food points'
    ),
    (
      '💌',
      'K-Food 레시피로 초대장 보내기',
      'Send a K-Food invite',
      '난이도 점수의 2배 보너스',
      'Double the difficulty bonus'
    ),
    (
      '📅',
      '주간 미션 달성',
      'Complete weekly mission',
      '7일간 요리 3회 + 초대 이용 시 +1점',
      'Cook 3x + use Inbox in 7 days → +1 pt'
    ),
    (
      '🥕',
      '냉장고에 첫 재료 등록',
      'Add your first fridge item',
      '+1점 (1회 한정)',
      '+1 pt (one-time)'
    ),
    (
      '🧊',
      '냉장고 재료만으로 레시피 완성',
      'Cook using only fridge items',
      '+1점 보너스',
      '+1 pt bonus'
    ),
    (
      '✨',
      '처음 도전하는 레시피 완성',
      'Try a new recipe for the first time',
      '+1점 보너스',
      '+1 pt bonus'
    ),
    (
      '❤️',
      '게시판 글이 좋아요 받기',
      'Get likes on a board post',
      '좋아요 10개당 +1점',
      '+1 pt per 10 likes'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (final rule in _rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(rule.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(rule.$2, rule.$3),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: AppColors.ink),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tr(rule.$4, rule.$5),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PointEventRow extends StatelessWidget {
  final PointEvent event;
  const _PointEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(event.labelKo, event.labelEn),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_timeAgoLabel(event.timestamp)} · ${event.isKFoodTrack ? tr("K-Food 포인트", "K-Food points") : tr("일반 포인트", "General points")}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.inkSoft, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(999)),
            child: Text(
              '+${event.amount}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }
}
