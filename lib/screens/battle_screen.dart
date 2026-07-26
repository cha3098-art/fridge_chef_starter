import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/battle.dart';
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
  List<Battle> _battles = [];
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
      final battles = await BattleStore.instance.fetchMyBattles();
      if (!mounted) return;
      setState(() {
        _battles = battles;
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
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BattleDetailScreen(battleId: battle.id)));
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
        title: Text(tr('요리 배틀', 'Cooking Battle'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
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
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.red),
                            ),
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
                : _battles.isEmpty
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
                                  tr('아직 참여 중인 배틀이 없어요', 'No battles yet'),
                                  style:
                                      const TextStyle(color: AppColors.inkSoft),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  tr('상대를 초대해서 요리 대결을 시작해보세요!',
                                      'Invite someone to start a cooking battle!'),
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
                            AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                        itemCount: _battles.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final battle = _battles[index];
                          return _BattleCard(
                            battle: battle,
                            title: battle.themeTitle ??
                                tr('자유 주제 배틀', 'Freestyle battle'),
                            onTap: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => BattleDetailScreen(
                                          battleId: battle.id)));
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
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const QuickMatchScreen()));
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

class _BattleCard extends StatelessWidget {
  final Battle battle;
  final String title;
  final VoidCallback onTap;
  const _BattleCard(
      {required this.battle, required this.title, required this.onTap});

  String _statusLabel(BattleStatus status) => switch (status) {
        BattleStatus.waitingOpponent => tr('상대 기다리는 중', 'Waiting for opponent'),
        BattleStatus.submitted => tr('진행 중', 'In progress'),
        BattleStatus.voting => tr('투표 중', 'Voting open'),
        BattleStatus.completed => tr('종료됨', 'Completed'),
        BattleStatus.cancelled => tr('취소됨', 'Cancelled'),
      };

  Color _statusColor(BattleStatus status) => switch (status) {
        BattleStatus.waitingOpponent => AppColors.inkSoft,
        BattleStatus.submitted => AppColors.carrot,
        BattleStatus.voting => AppColors.gold,
        BattleStatus.completed => AppColors.green,
        BattleStatus.cancelled => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: cardDecoration(radius: AppSpacing.radiusLg),
        child: Row(
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Text(_statusLabel(battle.status),
                      style: TextStyle(
                          fontSize: 12,
                          color: _statusColor(battle.status),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

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
                  child: Text(r.isKFood ? '🇰🇷 ${r.title}' : r.title))),
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
                hintText: tr('예: 매운 음식 대결', 'e.g. Spiciest dish challenge'),
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
              child: Text(tr('배틀 만들고 초대 링크 생성', 'Create battle & invite link'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
