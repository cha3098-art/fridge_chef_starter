import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/battle.dart';
import '../models/battle_list_item.dart';
import '../services/battle_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fridge_mascot.dart';
import 'battle_detail_screen.dart';
import 'quick_match_screen.dart';

/// 내 배틀 목록 + 새 배틀 만들기(초대 링크 기반) + 빠른 매칭(실시간 대기열 기반).
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  List<BattleListItem> _items = [];
  bool _loaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final items = await BattleStore.instance.fetchMyBattleItems();
      if (!mounted) return;
      setState(() {
        _items = items;
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
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: !_loaded
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.green))
            : _errorMessage != null
                ? ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          children: [
                            const FridgeMascot(size: 84),
                            const SizedBox(height: AppSpacing.md),
                            Text(_errorMessage!,
                                style:
                                    const TextStyle(color: AppColors.red)),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _load,
                              child: Text(tr('다시 시도', 'Try again')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          const SizedBox(height: 60),
                          Center(
                            child: Column(
                              children: [
                                const FridgeMascot(size: 84),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  tr('아직 참여 중인 배틀이 없어요',
                                      'No battles yet'),
                                  style: const TextStyle(
                                      color: AppColors.inkSoft),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tr('상대를 초대하거나 빠른 매칭으로 대결을 시작해보세요!',
                                      'Invite someone or use Quick Match to start!'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.inkSoft, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _BattleCard(
                            item: item,
                            onTap: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => BattleDetailScreen(
                                          battleId: item.battle.id)));
                              _load();
                            },
                          );
                        },
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
}

// ── 배틀 목록 카드 ─────────────────────────────────────────────────────────────

class _BattleCard extends StatelessWidget {
  final BattleListItem item;
  final VoidCallback onTap;

  const _BattleCard({required this.item, required this.onTap});

  (String, Color) get _statusTag => switch (item.battle.status) {
        BattleStatus.waitingOpponent =>
          (tr('매칭 전', 'Finding match'), AppColors.inkSoft),
        BattleStatus.submitted =>
          (tr('매칭 중', 'In progress'), AppColors.carrot),
        BattleStatus.voting =>
          (tr('투표 중', 'Voting'), AppColors.gold),
        BattleStatus.completed =>
          (tr('종료', 'Ended'), AppColors.green),
        BattleStatus.cancelled =>
          (tr('취소', 'Cancelled'), AppColors.red),
      };

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusTag;
    final battle = item.battle;
    final challenger = item.challengerNickname;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: cardDecoration(radius: AppSpacing.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3), width: 1),
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
            const SizedBox(height: 12),
            // VS row
            Row(
              children: [
                Expanded(
                  child: _NicknameChip(
                    nickname: item.hostNickname,
                    label: tr('호스트', 'Host'),
                    align: CrossAxisAlignment.start,
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
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
                  ),
                ),
              ],
            ),
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

  const _NicknameChip({
    required this.nickname,
    required this.label,
    required this.align,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
            color: isPlaceholder ? AppColors.inkSoft : AppColors.ink,
            fontStyle:
                isPlaceholder ? FontStyle.italic : FontStyle.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
    final title = _selectedRecipe ??
        (freeTitle.isEmpty ? tr('자유 주제 배틀', 'Freestyle battle') : freeTitle);
    Navigator.pop(context, (themeTitle: title, recipeId: null as String?));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  value: null, child: Text(tr('자유 주제', 'Freestyle'))),
              ...allRecipes.map((r) => DropdownMenuItem<String?>(
                  value: r.title,
                  child: Text(r.isKFood
                      ? '🇰🇷 ${tr(r.title, r.titleEn)}'
                      : tr(r.title, r.titleEn)))),
            ],
            onChanged: (v) => setState(() => _selectedRecipe = v),
          ),
          if (_selectedRecipe == null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _themeController,
              style: const TextStyle(color: AppColors.ink),
              decoration: InputDecoration(
                labelText: tr('배틀 제목', 'Battle title'),
                hintText:
                    tr('예: 매운 음식 대결', 'e.g. Spiciest dish challenge'),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.green, width: 1.5),
                ),
              ),
            ),
          ],
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
