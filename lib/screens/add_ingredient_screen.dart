import 'package:flutter/material.dart';
import '../data/ingredient_catalog.dart';
import '../models/fridge_item.dart';
import '../theme/app_theme.dart';

/// "재료 등록" 화면 — 검색 / 사진인식 / 영수증스캔 세 가지 방법을 탭으로 제공
/// 검색 탭은 로컬 카탈로그 기반으로 실제 동작하며, 담은 재료를 냉장고 화면으로 반환한다.
/// 사진인식·영수증스캔은 OCR/이미지 인식 백엔드가 아직 없어 준비 중 화면으로 대체했다.
class AddIngredientScreen extends StatefulWidget {
  const AddIngredientScreen({super.key});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final List<FridgeItem> _cart = [];

  void _addToCart(FridgeItem item) => setState(() => _cart.add(item));

  void _removeFromCart(int index) => setState(() => _cart.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          title: const Text('재료 등록'),
          bottom: const TabBar(
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.green,
            tabs: [
              Tab(text: '검색'),
              Tab(text: '사진인식'),
              Tab(text: '영수증스캔'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SearchTab(cart: _cart, onAdd: _addToCart, onRemove: _removeFromCart),
            const _ComingSoonTab(
              icon: Icons.camera_alt_outlined,
              title: '사진으로 재료 인식',
              description: '냉장고 속 재료 사진을 찍으면\n자동으로 인식해서 등록해줘요.\n(준비 중인 기능이에요)',
              buttonLabel: '사진 촬영하기',
            ),
            const _ComingSoonTab(
              icon: Icons.receipt_long_outlined,
              title: '영수증으로 한번에 등록',
              description: '장 본 영수증을 스캔하면\n항목을 자동으로 인식해서 등록해줘요.\n(준비 중인 기능이에요)',
              buttonLabel: '영수증 촬영하기',
            ),
          ],
        ),
        bottomNavigationBar: _cart.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _cart),
                    child: Text('냉장고에 담기 · ${_cart.length}개'),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SearchTab extends StatefulWidget {
  final List<FridgeItem> cart;
  final ValueChanged<FridgeItem> onAdd;
  final ValueChanged<int> onRemove;

  const _SearchTab({required this.cart, required this.onAdd, required this.onRemove});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  String _query = '';

  List<IngredientCatalogEntry> get _filtered {
    if (_query.isEmpty) return ingredientCatalog;
    return ingredientCatalog.where((e) => e.name.contains(_query)).toList();
  }

  Future<void> _openQuantitySheet(IngredientCatalogEntry entry) async {
    final result = await showModalBottomSheet<FridgeItem>(
      context: context,
      backgroundColor: const Color(0xFFFFFEFB),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _QuantitySheet(entry: entry),
    );
    if (result != null) widget.onAdd(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: '재료 이름으로 검색',
              prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft),
              filled: true,
              fillColor: const Color(0xFFFFFEFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        if (widget.cart.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < widget.cart.length; i++)
                    Chip(
                      label: Text(
                        '${widget.cart[i].name} ${widget.cart[i].quantityLabel}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: AppColors.greenSoft,
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => widget.onRemove(i),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Text('검색 결과가 없어요', style: TextStyle(color: AppColors.inkSoft)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, index) {
                    final entry = _filtered[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        entry.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        entry.category,
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                      ),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.green),
                      onTap: () => _openQuantitySheet(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _QuantitySheet extends StatefulWidget {
  final IngredientCatalogEntry entry;

  const _QuantitySheet({required this.entry});

  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  late final TextEditingController _qtyController;
  late final TextEditingController _unitController;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: widget.entry.unitDefault);
    final shelfLife = widget.entry.defaultShelfLifeDays;
    _expiryDate = shelfLife != null ? DateTime.now().add(Duration(days: shelfLife)) : null;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _confirm() {
    final qty = double.tryParse(_qtyController.text) ?? 1;
    final unit = _unitController.text.trim();
    Navigator.pop(
      context,
      FridgeItem(
        name: widget.entry.name,
        quantity: qty,
        unit: unit.isEmpty ? widget.entry.unitDefault : unit,
        expiryDate: _expiryDate,
        category: widget.entry.category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.entry.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '수량'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(labelText: '단위'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '유통기한'),
              child: Text(
                _expiryDate == null
                    ? '설정 안 함'
                    : '${_expiryDate!.year}.${_expiryDate!.month.toString().padLeft(2, '0')}.${_expiryDate!.day.toString().padLeft(2, '0')}',
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _confirm, child: const Text('담기')),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;

  const _ComingSoonTab({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.paperDeep, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('빠른 시일 내에 만나볼 수 있어요!')),
                );
              },
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
