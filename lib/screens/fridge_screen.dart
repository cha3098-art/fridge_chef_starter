import 'package:flutter/material.dart';
import '../models/fridge_item.dart';
import '../theme/app_theme.dart';
import 'add_ingredient_screen.dart';

/// UI디자인_v2/v3의 "01 · 내 냉장고" 화면을 Flutter 위젯으로 구현한 시작 코드
/// 실제 데이터는 Supabase의 user_ingredients 테이블에서 불러오도록 연결 예정
class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  // TODO: Supabase에서 실제 재료 목록을 불러오도록 교체
  final List<FridgeItem> _items = [
    FridgeItem(
      name: '계란',
      quantity: 10,
      unit: '개',
      expiryDate: DateTime.now().add(const Duration(days: 6)),
      category: '유제품',
    ),
    FridgeItem(
      name: '대파',
      quantity: 0.5,
      unit: '단',
      expiryDate: DateTime.now().add(const Duration(days: 2)),
      category: '채소',
    ),
    FridgeItem(
      name: '두부',
      quantity: 1,
      unit: '모',
      expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      category: '기타',
    ),
    FridgeItem(
      name: '돼지고기 앞다리살',
      quantity: 300,
      unit: 'g',
      expiryDate: DateTime.now().add(const Duration(days: 4)),
      category: '육류',
    ),
  ];

  Future<void> _openAddIngredient() async {
    final added = await Navigator.of(context).push<List<FridgeItem>>(
      MaterialPageRoute(builder: (_) => const AddIngredientScreen()),
    );
    if (added != null && added.isNotEmpty) {
      setState(() => _items.addAll(added));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _items.where((i) => i.ddayLevel == DdayLevel.bad).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: Text('내 냉장고 · ${_items.length}'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: AppColors.paperDeep,
              child: Icon(Icons.settings, size: 18, color: AppColors.ink),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(label: '전체 ${_items.length}', active: true),
                  const _CategoryChip(label: '채소'),
                  const _CategoryChip(label: '육류'),
                  const _CategoryChip(label: '유제품'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFB),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: _items.map((item) => _FridgeItemTile(item: item)).toList(),
              ),
            ),
            if (expired.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
                  const SizedBox(width: 4),
                  Text(
                    '${expired.first.name} 유통기한 지남 · ',
                    style: const TextStyle(fontSize: 11, color: AppColors.red),
                  ),
                  const Text(
                    '바로 구매하기',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: _openAddIngredient,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppColors.green,
        unselectedItemColor: AppColors.inkSoft,
        backgroundColor: const Color(0xFFFFFEFB),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: '냉장고'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '추천'),
          BottomNavigationBarItem(icon: Icon(Icons.mail_outline), label: '초대함'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이'),
        ],
      ),
    );
  }
}

class _FridgeItemTile extends StatelessWidget {
  final FridgeItem item;
  const _FridgeItemTile({required this.item});

  Color _bg() {
    switch (item.ddayLevel) {
      case DdayLevel.ok:
        return AppColors.greenSoft;
      case DdayLevel.warn:
        return AppColors.goldSoft;
      case DdayLevel.bad:
        return AppColors.redSoft;
    }
  }

  Color _fg() {
    switch (item.ddayLevel) {
      case DdayLevel.ok:
        return AppColors.green;
      case DdayLevel.warn:
        return const Color(0xFF9C6A15);
      case DdayLevel.bad:
        return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(item.quantityLabel, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _bg(), borderRadius: BorderRadius.circular(6)),
            child: Text(
              item.ddayLabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _fg()),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  const _CategoryChip({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? AppColors.ink : AppColors.paperDeep,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? AppColors.ink : AppColors.line),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFFFBF8F1) : AppColors.inkSoft,
        ),
      ),
    );
  }
}
