import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// UI디자인_v2/v3의 "01 · 내 냉장고" 화면을 Flutter 위젯으로 구현한 시작 코드
/// 실제 데이터는 Supabase의 user_ingredients 테이블에서 불러오도록 연결 예정
class FridgeScreen extends StatelessWidget {
  const FridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Supabase에서 실제 재료 목록을 불러오도록 교체
    final items = [
      _FridgeItem('계란', '10개', 'D-6', _DdayLevel.ok),
      _FridgeItem('대파', '1/2단', 'D-2', _DdayLevel.warn),
      _FridgeItem('두부', '1모', '만료', _DdayLevel.bad),
      _FridgeItem('돼지고기 앞다리살', '300g', 'D-4', _DdayLevel.ok),
    ];

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        title: const Text('내 냉장고 · 12'),
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
                children: const [
                  _CategoryChip(label: '전체 12', active: true),
                  _CategoryChip(label: '채소'),
                  _CategoryChip(label: '육류'),
                  _CategoryChip(label: '유제품'),
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
                children: items
                    .map((item) => _FridgeItemTile(item: item))
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.red),
                const SizedBox(width: 4),
                const Text('두부 유통기한 지남 · ', style: TextStyle(fontSize: 11, color: AppColors.red)),
                Text(
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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () {
          // TODO: 재료 등록 화면으로 이동 (검색 / 사진인식 / 영수증스캔)
        },
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

enum _DdayLevel { ok, warn, bad }

class _FridgeItem {
  final String name;
  final String qty;
  final String dday;
  final _DdayLevel level;
  _FridgeItem(this.name, this.qty, this.dday, this.level);
}

class _FridgeItemTile extends StatelessWidget {
  final _FridgeItem item;
  const _FridgeItemTile({required this.item});

  Color _bg() {
    switch (item.level) {
      case _DdayLevel.ok:
        return AppColors.greenSoft;
      case _DdayLevel.warn:
        return AppColors.goldSoft;
      case _DdayLevel.bad:
        return AppColors.redSoft;
    }
  }

  Color _fg() {
    switch (item.level) {
      case _DdayLevel.ok:
        return AppColors.green;
      case _DdayLevel.warn:
        return const Color(0xFF9C6A15);
      case _DdayLevel.bad:
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
              Text(item.qty, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _bg(), borderRadius: BorderRadius.circular(6)),
            child: Text(
              item.dday,
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
