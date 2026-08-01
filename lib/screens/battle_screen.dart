import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/battle.dart';
import '../models/battle_list_item.dart';
import '../services/battle_store.dart';
import '../theme/app_theme.dart';
import '../utils/battle_countdown.dart';
import '../widgets/battle_split_banner.dart';
import '../widgets/fridge_mascot.dart';
import 'battle_detail_screen.dart';
import 'quick_match_screen.dart';

/// 내 배틀 목록 + 진행 중인 모든 배틀(참여/투표) + 새 배틀 만들기 + 빠른 매칭.
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<BattleListItem> _myItems = [];
  List<BattleListItem> _openItems = [];
  bool _loaded = false;
  String? _errorMessage;

  String? get _myUid => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final results = await Future.wait([
        BattleStore.instance.fetchMyBattleItems(),
        BattleStore.instance.fetchOpenBattleItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _myItems = results[0];
        _openItems = results[1];
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = tr('배틀 목록을 불러오지 못했어요', 'Could not load battles');
        _loaded = true;
      });
    }
  }

  Future<void> _openCreateSheet() async {
    final draft =
        await showModalBottomSheet<({String themeTitle, String? recipeId})>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _CreateBattleSheet(),
    );
    if (draft == null || !mounted) return;

    late final Battle battle;
    try {
      battle = await BattleStore.instance
          .createBattle(recipeId: draft.recipeId, themeTitle: draft.themeTitle);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('배틀 생성에 실패했어요', 'Could not create the battle'))),
      );
      return;
    }
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: battle.inviteLink ?? ''));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('배틀을 만들고 초대 링크를 복사했어요',
              'Battle created and invite link copied'))),
    );
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BattleDetailScreen(battleId: battle.id)));
    _load();
  }

  Future<void> _vote(BattleListItem item, String participantId) async {
    try {
      await BattleStore.instance
          .vote(battleId: item.battle.id, participantId: participantId);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('투표에 실패했어요', 'Could not submit the vote'))),
      );
    }
  }

  Future<void> _copyInvite(Battle battle) async {
    if (battle.inviteLink == null) return;
    await Clipboard.setData(ClipboardData(text: battle.inviteLink!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('초대 링크를 복사했어요', 'Invite link copied'))),
    );
  }

  Future<void> _join(BattleListItem item) async {
    try {
      await BattleStore.instance.joinBattle(item.battle.id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BattleDetailScreen(battleId: item.battle.id)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('참여에 실패했어요 (이미 상대가 있을 수 있어요)',
                'Could not join (opponent slot may be taken)'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 76,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/icon/icon_challenge_rival.png',
                  width: 58, height: 58, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text(tr('요리 배틀', 'Cooking Battle'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.paperDeep,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.inkSoft,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(text: tr('내 배틀', 'My Battles')),
                  Tab(text: tr('전체 배틀', 'All Battles')),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: !_loaded
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green))
            : _errorMessage != null
                ? _buildError()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(
                        items: _myItems,
                        emptyTitle:
                            tr('아직 참여 중인 배틀이 없어요', 'No battles yet'),
                        emptySubtitle: tr('상대를 초대하거나 빠른 매칭으로 대결을 시작해보세요!',
                            'Invite someone or use Quick Match to start!'),
                      ),
                      _buildList(
                        items: _openItems,
                        emptyTitle: tr(
                            '진행 중인 배틀이 없어요', 'No battles happening right now'),
                        emptySubtitle: tr('새 배틀을 만들어서 첫 대결을 시작해보세요!',
                            'Create the first battle and get things started!'),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'quickMatch',
            elevation: 0,
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.ink,
            onPressed: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuickMatchScreen()));
              _load();
            },
            icon: const Icon(Icons.bolt_outlined, size: 20),
            label: Text(tr('빠른 매칭', 'Quick Match'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: -0.3)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'createBattle',
            elevation: 0,
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            onPressed: _openCreateSheet,
            icon: const Icon(Icons.add, size: 20),
            label: Text(tr('새 배틀 만들기', 'New Battle'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, letterSpacing: -0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              const FridgeMascot(size: 84),
              const SizedBox(height: AppSpacing.md),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.red)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                child: Text(tr('다시 시도', 'Try again')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList({
    required List<BattleListItem> items,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                const FridgeMascot(size: 84),
                const SizedBox(height: AppSpacing.md),
                Text(emptyTitle, style: const TextStyle(color: AppColors.inkSoft)),
                const SizedBox(height: 6),
                Text(
                  emptySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return _BattleCard(
          item: item,
          myUid: _myUid,
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BattleDetailScreen(battleId: item.battle.id)));
            _load();
          },
          onVote: (participantId) => _vote(item, participantId),
          onCopyInvite: () => _copyInvite(item.battle),
          onJoin: () => _join(item),
        );
      },
    );
  }
}

// ── 배틀 목록 카드 ─────────────────────────────────────────────────────────────

class _BattleCard extends StatelessWidget {
  final BattleListItem item;
  final String? myUid;
  final VoidCallback onTap;
  final ValueChanged<String> onVote;
  final VoidCallback onCopyInvite;
  final VoidCallback onJoin;

  const _BattleCard({
    required this.item,
    required this.myUid,
    required this.onTap,
    required this.onVote,
    required this.onCopyInvite,
    required this.onJoin,
  });

  /// 상대를 기다리는 중이면 매칭 만료(1일)까지, 투표가 진행 중이면 배틀 종료(2일)까지
  /// 남은 시간을 보여준다 — 그 외 상태에서는 표시하지 않는다.
  String? get _countdownText {
    final battle = item.battle;
    if (battle.status == BattleStatus.waitingOpponent) {
      final remaining =
          battle.createdAt.add(const Duration(days: 1)).difference(DateTime.now());
      if (remaining.isNegative) return null;
      return tr('매칭 마감 ${formatBattleCountdown(remaining)}',
          'Match closes: ${formatBattleCountdown(remaining)}');
    }
    if ((battle.status == BattleStatus.submitted ||
            battle.status == BattleStatus.voting) &&
        battle.votingEndsAt != null) {
      final remaining = battle.votingEndsAt!.difference(DateTime.now());
      if (remaining.isNegative) return null;
      return tr('배틀 종료 ${formatBattleCountdown(remaining)}',
          'Battle ends: ${formatBattleCountdown(remaining)}');
    }
    return null;
  }

  (String, Color) get _statusTag => switch (item.battle.status) {
        BattleStatus.waitingOpponent =>
          (tr('매칭 전', 'Finding match'), AppColors.inkSoft),
        BattleStatus.submitted =>
          (tr('매칭 중 · 투표 가능', 'In progress · Votable'), AppColors.carrot),
        BattleStatus.voting =>
          (tr('투표 중', 'Voting'), AppColors.gold),
        BattleStatus.completed =>
          (tr('매칭 종료', 'Ended'), AppColors.green),
        BattleStatus.cancelled =>
          (tr('취소', 'Cancelled'), AppColors.red),
      };

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusTag;
    final battle = item.battle;
    final challenger = item.challengerNickname;
    final isSubmitted = battle.status == BattleStatus.submitted;
    final isVoting = battle.status == BattleStatus.voting;
    final isCompleted = battle.status == BattleStatus.completed;
    final isWaiting = battle.status == BattleStatus.waitingOpponent;
    // 매칭이 성사된(상대가 들어온) 순간부터 배틀이 끝나기 전까지는 계속 투표할 수 있다 —
    // 사진을 아직 안 올렸어도 상관없다. "투표 가능"과 "사진 제출 완료"는 서로 다른 조건이다.
    final isVotable = isSubmitted || isVoting;

    final iAmHost = item.myParticipantId != null &&
        item.myParticipantId == item.hostParticipantId;

    // 투표는 참가자 두 명끼리만이 아니라 관객으로 로그인한 누구나 할 수 있다 — 단, 본인
    // 요리에는 투표할 수 없다 (battle_detail_screen.dart의 canVote 규칙과 동일).
    final canVoteHost = isVotable &&
        item.hostParticipantId != null &&
        myUid != null &&
        myUid != battle.hostUserId;
    final canVoteChallenger = isVotable &&
        item.challengerParticipantId != null &&
        myUid != null &&
        myUid != item.challengerUserId;
    final votedHost = item.myVoteParticipantId != null &&
        item.myVoteParticipantId == item.hostParticipantId;
    final votedChallenger = item.myVoteParticipantId != null &&
        item.myVoteParticipantId == item.challengerParticipantId;

    final showInvite =
        isWaiting && iAmHost && challenger == null && battle.inviteLink != null;

    // 상대 자리가 비어 있고 나는 아직 이 배틀의 참가자가 아니면(호스트도 아니고 이미
    // 들어간 것도 아니면) 목록에서 바로 참여할 수 있다 — "전체 배틀" 탭의 핵심 액션.
    final showJoin = isWaiting &&
        challenger == null &&
        item.myParticipantId == null &&
        myUid != null;

    return InkWell(
      // 상대가 없는 배틀은 카드 어디를 눌러도 바로 참여된다 — "리스트를 누르면 참여"라는
      // 요청을 그대로 반영. 그 외 상태에서는 기존대로 상세 화면으로 이동한다.
      onTap: showJoin ? onJoin : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 중심 배틀 카드 — 두 참가자의 마스코트를 대각선으로 슬래시 컷해서
            // 붙이고 가운데 ⚔️ VS 배지를 겹쳐서, 한눈에 "요리 대결"임을 알 수 있게 한다.
            BattleSplitBanner(
              hostUserId: battle.hostUserId,
              hostGender: item.hostGender,
              challengerUserId: item.challengerUserId,
              challengerGender: item.challengerGender,
            ),
            const SizedBox(height: 12),
            // Title + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    battle.themeTitle ?? tr('자유 주제 배틀', 'Freestyle battle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4), width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: statusColor.withValues(alpha: 0.25),
                          blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            if (_countdownText != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 12, color: AppColors.greenDeep),
                  const SizedBox(width: 3),
                  Text(_countdownText!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.greenDeep)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // VS row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _NicknameChip(
                    nickname: item.hostNickname,
                    label: tr('호스트', 'Host'),
                    align: CrossAxisAlignment.start,
                    voteCount: item.hostVotes,
                    showVoteCount: isVotable || isCompleted,
                    canVote: canVoteHost,
                    voted: votedHost,
                    onTap: canVoteHost && !votedHost
                        ? () => onVote(item.hostParticipantId!)
                        : null,
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(top: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.paperDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line, width: 1),
                  ),
                  child: const Text('⚔️', style: TextStyle(fontSize: 16)),
                ),
                Expanded(
                  child: _NicknameChip(
                    nickname: challenger ?? tr('대기 중…', 'Waiting…'),
                    label: tr('상대', 'Opponent'),
                    align: CrossAxisAlignment.end,
                    isPlaceholder: challenger == null,
                    voteCount: item.challengerVotes,
                    showVoteCount:
                        challenger != null && (isVotable || isCompleted),
                    canVote: canVoteChallenger,
                    voted: votedChallenger,
                    onTap: canVoteChallenger && !votedChallenger
                        ? () => onVote(item.challengerParticipantId!)
                        : null,
                  ),
                ),
              ],
            ),
            if (showInvite) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: onCopyInvite,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.greenDeep,
                    side: const BorderSide(color: AppColors.green, width: 1.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.link, size: 15),
                  label: Text(tr('초대 링크 복사', 'Copy invite link'),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
            if (showJoin) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.bolt, size: 14),
                  label: Text(tr('참여하기', 'Join battle'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Footer: time ago + chevron
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(battle.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.inkSoft),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.inkSoft, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return tr('방금 전', 'just now');
    if (diff.inHours < 1) return tr('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
    if (diff.inDays < 1) return tr('${diff.inHours}시간 전', '${diff.inHours}h ago');
    return tr('${diff.inDays}일 전', '${diff.inDays}d ago');
  }
}

class _NicknameChip extends StatelessWidget {
  final String nickname;
  final String label;
  final CrossAxisAlignment align;
  final bool isPlaceholder;
  final int voteCount;
  final bool showVoteCount;
  final bool canVote;
  final bool voted;
  final VoidCallback? onTap;

  const _NicknameChip({
    required this.nickname,
    required this.label,
    required this.align,
    this.isPlaceholder = false,
    this.voteCount = 0,
    this.showVoteCount = false,
    this.canVote = false,
    this.voted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTappable = onTap != null;
    final content = Column(
      crossAxisAlignment: align,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(
          nickname,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isPlaceholder
                ? AppColors.inkSoft
                : isTappable
                    ? AppColors.green
                    : AppColors.ink,
            decoration: isTappable ? TextDecoration.underline : null,
            decorationColor: AppColors.green,
            fontStyle:
                isPlaceholder ? FontStyle.italic : FontStyle.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showVoteCount) ...[
          const SizedBox(height: 3),
          // 투표 가능하면 "눌러서 투표" 안내로, 이미 투표했거나 남의 투표 상황을 볼 때는
          // 득표수로 — 사람 이름(칩) 어디를 눌러도 같은 동작이라 별도 버튼이 필요 없다.
          if (canVote && !voted)
            Text(tr('👆 눌러서 투표', '👆 Tap to vote'),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: align == CrossAxisAlignment.end
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Text(voted ? '✓' : '🗳️', style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text('$voteCount${tr('표', '')}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: voted ? AppColors.green : AppColors.carrot)),
              ],
            ),
        ],
      ],
    );

    if (!isTappable) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

// ── 배틀 만들기 바텀시트 ────────────────────────────────────────────────────────

class _CreateBattleSheet extends StatefulWidget {
  const _CreateBattleSheet();

  @override
  State<_CreateBattleSheet> createState() => _CreateBattleSheetState();
}

class _CreateBattleSheetState extends State<_CreateBattleSheet> {
  String? _selectedRecipe;
  late final TextEditingController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = TextEditingController();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  void _confirm() {
    final freeTitle = _themeController.text.trim();
    final title = freeTitle.isNotEmpty
        ? freeTitle
        : (_selectedRecipe ?? tr('자유 주제 배틀', 'Freestyle battle'));
    Navigator.pop(context, (themeTitle: title, recipeId: null as String?));
  }

  @override
  Widget build(BuildContext context) {
    // 키보드가 올라오거나 작은 화면에서 드롭다운+입력폼+버튼 전체 높이가 뷰포트를
    // 넘기면 오버플로우가 나므로, 시트 전체를 스크롤 가능하게 감싼다.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(tr('배틀 만들기', 'New Battle'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String?>(
            initialValue: _selectedRecipe,
            elevation: 2,
            dropdownColor: AppColors.card,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
            // 긴 레시피 제목이 기본 itemHeight(48)를 넘어 두 줄로 감기면서
            // RenderFlex가 "BOTTOM OVERFLOWED BY 13 PIXELS"를 내던 문제 수정:
            // isExpanded로 남는 폭을 다 쓰게 하고, itemHeight를 null로 풀어
            // 각 항목이 내용에 맞는 높이를 스스로 갖게 한다(Flutter 권장 해결책).
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              labelText: tr('레시피 주제 (선택)', 'Recipe theme (optional)'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
            items: [
              DropdownMenuItem<String?>(
                  value: null,
                  child: Text(tr('자유 주제', 'Freestyle'),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              ...allRecipes.map((r) => DropdownMenuItem<String?>(
                  value: r.title,
                  child: Text(
                      r.isKFood
                          ? '🇰🇷 ${tr(r.title, r.titleEn)}'
                          : tr(r.title, r.titleEn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() {
              _selectedRecipe = v;
              // 레시피를 고르면 제목을 비워둔 사람에게만 레시피명을 기본값으로 채워준다 —
              // 이미 직접 쓴 제목은 덮어쓰지 않는다.
              if (v != null && _themeController.text.trim().isEmpty) {
                _themeController.text = v;
              }
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _themeController,
            style: const TextStyle(color: AppColors.ink),
            decoration: InputDecoration(
              labelText: tr('배틀 제목', 'Battle title'),
              hintText: _selectedRecipe != null
                  ? tr('비워두면 "$_selectedRecipe"로 등록돼요',
                      'Leave blank to use "$_selectedRecipe"')
                  : tr('예: 매운 음식 대결', 'e.g. Spiciest dish challenge'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _confirm,
              child: Text(
                  tr('배틀 만들고 초대 링크 생성',
                      'Create battle & invite link'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
