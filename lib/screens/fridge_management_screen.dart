import 'package:flutter/material.dart';

import '../l10n/recipe_i18n.dart';
import '../l10n/tr.dart';
import '../models/fridge_item.dart';
import '../services/chef_points_store.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'add_ingredient_screen.dart';

/// "냉장고관리" — 냉장고/냉동고 저장 위치를 먼저 고르고, 세부 분류(육류/유제품/야채/생선/
/// 밑반찬/소스/기타) 칩으로 좁혀가며 실제 보유 재료를 확인하는 화면. FridgeStore를 직접
/// 구독해 재료등록/삭제가 실시간으로 반영된다.
class FridgeManagementScreen extends StatefulWidget {
  /// true면 상위 카테고리 화면(세그먼트 탭)에 본문만 끼워 넣는 모드 — "재료 등록"이
  /// 이미 옆 탭으로 존재하므로 이 화면 자체의 FAB은 생략한다.
  final bool embed;

  const FridgeManagementScreen({super.key, this.embed = false});

  @override
  State<FridgeManagementScreen> createState() => _FridgeManagementScreenState();
}

class _FridgeManagementScreenState extends State<FridgeManagementScreen> {
  StorageLocation _location = StorageLocation.fridge;
  String? _category; // null = 전체

  @override
  void initState() {
    super.initState();
    if (!FridgeStore.instance.isLoaded) FridgeStore.instance.loadItems();
  }

  Future<void> _openAddIngredient() async {
    final added = await Navigator.of(context).push<List<FridgeItem>>(
      MaterialPageRoute(builder: (_) => const AddIngredientScreen()),
    );
    if (added != null && added.isNotEmpty) {
      final ok = await FridgeStore.instance.addItems(added);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FridgeStore.instance.error ??
                tr('냉장고에 담지 못했어요. 다시 시도해주세요', 'Could not add to your fridge. Please try again')),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }
      ChefPointsStore.instance.recordFirstIngredientIfNeeded();
    }
  }

  Widget _buildBody(BuildContext context, List<FridgeItem> filtered) {
    return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  children: StorageLocation.values.map((loc) {
                    final selected = loc == _location;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: loc == StorageLocation.values.first ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _location = loc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? AppColors.ink : AppColors.paperDeep,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: selected
                                      ? AppColors.ink
                                      : AppColors.cardBorder),
                            ),
                            child: Text(
                              loc == StorageLocation.fridge
                                  ? tr('❄️ 냉장고', '❄️ Fridge')
                                  : tr('🧊 냉동고', '🧊 Freezer'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.white : AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  children: [
                    _CategoryChip(
                      label: tr('전체', 'All'),
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final c in storageCategories) ...[
                      const SizedBox(width: 8),
                      _CategoryChip(
                        label: trTag(c),
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: !FridgeStore.instance.isLoaded
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.green))
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const FridgeMascot(size: 84),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                    tr('여기엔 아직 재료가 없어요', 'No ingredients here yet'),
                                    style: const TextStyle(
                                        color: AppColors.inkSoft, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md, 0, AppSpacing.md, 120),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final id = item.id;
                              final row = _FridgeItemRow(item: item);
                              if (id == null) return row;
                              return Dismissible(
                                key: ValueKey(id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                      color: AppColors.redSoft,
                                      borderRadius: BorderRadius.circular(14)),
                                  child: const Icon(Icons.delete_outline_rounded,
                                      color: AppColors.red),
                                ),
                                onDismissed: (_) =>
                                    FridgeStore.instance.deleteItem(id),
                                child: row,
                              );
                            },
                          ),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FridgeStore.instance, LocaleStore.instance]),
      builder: (context, _) {
        final allItems = FridgeStore.instance.items;
        final byLocation =
            allItems.where((i) => i.storageLocation == _location).toList();
        final filtered = _category == null
            ? byLocation
            : byLocation.where((i) => i.storageCategory == _category).toList();

        if (widget.embed) return _buildBody(context, filtered);

        return Scaffold(
          backgroundColor: AppColors.paper,
          floatingActionButton: Padding(
            padding: EdgeInsets.only(
                bottom: 95 + MediaQuery.of(context).padding.bottom),
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              onPressed: _openAddIngredient,
              icon: const Icon(Icons.add),
              label: Text(tr('재료 등록', 'Add ingredient'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          appBar: AppBar(
            leading: const LabeledBackButton(),
            leadingWidth: 96,
            backgroundColor: AppColors.paper,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 76,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/icon/icon_additem.png',
                      width: 58, height: 58, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(tr('냉장고 관리', 'Fridge Management'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.ink)),
                ),
              ],
            ),
            actions: const [
              Padding(
                  padding: EdgeInsets.only(right: 16), child: LanguageToggle()),
            ],
          ),
          body: _buildBody(context, filtered),
          extendBody: true,
          bottomNavigationBar: MainBottomNav(
            currentIndex: 1,
            fridgeIngredientNames: allItems.map((i) => i.name).toSet(),
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.paperDeep,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.green : AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _FridgeItemRow extends StatelessWidget {
  final FridgeItem item;
  const _FridgeItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: cardDropShadow(),
      ),
      child: Row(
        children: [
          IngredientAvatar(name: item.name, category: item.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trIngredientName(item.name),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('${item.quantityLabel} · ${trTag(item.storageCategory)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: item.ddayLevel.ddayBg,
                borderRadius: BorderRadius.circular(8)),
            child: Text(item.ddayLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: item.ddayLevel.ddayText)),
          ),
        ],
      ),
    );
  }
}
