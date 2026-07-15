import 'package:flutter/material.dart';
import '../l10n/tr.dart';
import '../models/fridge_item.dart';
import '../services/chef_points_store.dart';
import '../services/fridge_store.dart';
import '../services/locale_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/chef_tier_badge.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_bottom_nav.dart';
import 'add_ingredient_screen.dart';
import 'kfood_screen.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

const _fridgeCategories = ['전체', '채소', '육류', '유제품', '수산', '기타'];

class _FridgeScreenState extends State<FridgeScreen> {
  String _selectedCategory = '전체';

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
      await FridgeStore.instance.addItems(added);
      ChefPointsStore.instance.recordFirstIngredientIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FridgeStore.instance, LocaleStore.instance]),
      builder: (context, _) {
        if (!FridgeStore.instance.isLoaded) {
          return const Scaffold(
            backgroundColor: AppColors.paper,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final items = FridgeStore.instance.items;
        return _buildScaffold(context, items);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, List<FridgeItem> items) {
    final expired = items.where((i) => i.ddayLevel == DdayLevel.bad).toList();
    final visibleItems =
        _selectedCategory == '전체' ? items : items.where((i) => i.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // 더 밝고 투명감 있는 배경 (Slate 50)
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Text(
                tr('내 냉장고', 'My Fridge'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.ink),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.green),
                ),
              ),
            ],
          ),
        ),
        actions: const [
          LanguageToggle(),
          SizedBox(width: 4),
          ChefTierBadge(),
          SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(Icons.settings_outlined, size: 18, color: AppColors.ink),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. K-Food 배너 디자인 세련되게 전면 수정 (고급스러운 딥 네이비톤 모노크롬)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: const Color(0xFF1E293B), // 슬레이트 차콜 컬러로 변경해 트렌디함 부여
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => KFoodScreen(
                        fridgeIngredientNames: items.map((i) => i.name).toSet(),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('🇰🇷 K-RECIPE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr('K-Food 만들기', 'Make K-Food'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr('김치찌개부터 짜파구리까지, 대표 한식 레시피', 'From kimchi jjigae to jjapaguri'),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white60, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. 카테고리 탭 영역 (더 깔끔하고 모던한 가로 칩 스타일로 개선)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fridgeCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _fridgeCategories[index];
                final count = category == '전체'
                    ? items.length
                    : items.where((i) => i.category == category).length;
                final bool isActive = _selectedCategory == category;

                return _CategoryTabChip(
                  category: category,
                  label: category == '전체' ? tr('전체', 'All') : trTag(category),
                  count: count,
                  active: isActive,
                  onTap: () => setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          if (FridgeStore.instance.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEE2E2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        FridgeStore.instance.error!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => FridgeStore.instance.loadItems(),
                      child: Text(tr('다시 시도', 'Retry'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // 3. 재료 리스트 뷰 영역
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  const FridgeMascot(size: 88),
                  const SizedBox(height: 16),
                  Text(
                    tr('냉장고가 비어있어요', 'Your fridge is empty'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('오른쪽 아래 + 버튼으로 재료를 등록해보세요', 'Tap + below to add your first ingredient'),
                    style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (visibleItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  tr('이 카테고리엔 재료가 없어요', 'No items in this category'),
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
                ),
              ),
            )
          else
            // 통짜 카드 스타일 대신 각 재료를 개별 카드로 분리하여 입체감과 여백 확보
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final id = item.id;
                if (id == null) return _ModernFridgeItemCard(item: item);
                return Dismissible(
                  key: ValueKey(id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                  ),
                  onDismissed: (_) {
                    FridgeStore.instance.deleteItem(id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('${item.name}이(가) 삭제됐어요', '${item.name} deleted')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: _ModernFridgeItemCard(item: item),
                );
              },
            ),

          // 4. 유통기한 경고 알림 노티바 변경
          if (expired.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), // 부드러운 파스텔 레드 배경
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                        children: [
                          TextSpan(text: expired.first.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: ' ${tr('유통기한 지남', 'expired')}  ·  '),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      tr('바로 구매하기', 'Buy now'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.red,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80), // 하단 플로팅 버튼에 가려지지 않게 여백 추가
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        elevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _openAddIngredient,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text('재료 추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: 0,
        fridgeIngredientNames: items.map((i) => i.name).toSet(),
      ),
    );
  }
}

// 개별 아이템 카드를 독립 컴포넌트로 세련되게 빌드
class _ModernFridgeItemCard extends StatelessWidget {
  final FridgeItem item;
  const _ModernFridgeItemCard({required this.item});

  Color _ddayBg() {
    switch (item.ddayLevel) {
      case DdayLevel.ok: return const Color(0xFFDCFCE7); // 소프트 그린
      case DdayLevel.warn: return const Color(0xFFFEF9C3); // 소프트 옐로
      case DdayLevel.bad: return const Color(0xFFFEE2E2); // 소프트 레드
    }
  }

  Color _ddayText() {
    switch (item.ddayLevel) {
      case DdayLevel.ok: return const Color(0xFF15803D);
      case DdayLevel.warn: return const Color(0xFF854D0E);
      case DdayLevel.bad: return const Color(0xFFB91C1C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          // 기존 원형 아바타 사용하되 감싸는 레이아웃 정돈
          IngredientAvatar(name: item.name, category: item.category),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  item.quantityLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _ddayBg(),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.ddayLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _ddayText()),
            ),
          ),
        ],
      ),
    );
  }
}

// 복잡했던 원형 그래디언트 카테고리를 직관적이고 미니멀한 칩 형태로 전환
class _CategoryTabChip extends StatelessWidget {
  final String category;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _CategoryTabChip({
    required this.category,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: active ? [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          children: [
            Text(
              emojiForCategory(category),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
