import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ingredient_catalog.dart';
import '../l10n/tr.dart';
import '../models/fridge_item.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/language_toggle.dart';

/// "재료 등록" 화면 — 검색 / 사진인식 / 영수증스캔 / 냉장고 전체촬영 네 가지 방법을 탭으로 제공
/// 검색 탭은 로컬 카탈로그 기반으로 실제 동작하며, 담은 재료를 냉장고 화면으로 반환한다.
/// 사진인식·영수증스캔·냉장고 전체촬영은 실제 이미지 인식 AI 백엔드가 아직 없어
/// (냉장고 전체촬영은 사진 촬영/미리보기까지는 실제로 동작하고) 인식 자체는 준비 중으로 안내한다.
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
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          elevation: 0,
          title: Text(tr('재료 등록', 'Add Ingredients')),
          actions: const [
            Padding(padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.green,
            tabs: [
              Tab(text: tr('검색', 'Search')),
              Tab(text: tr('사진인식', 'Photo scan')),
              Tab(text: tr('영수증스캔', 'Receipt scan')),
              Tab(text: tr('냉장고 전체촬영', 'Whole fridge')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SearchTab(cart: _cart, onAdd: _addToCart, onRemove: _removeFromCart),
            _ComingSoonTab(
              icon: Icons.camera_alt_outlined,
              title: tr('사진으로 재료 인식', 'Recognize ingredients from a photo'),
              description: tr(
                '냉장고 속 재료 사진을 찍으면\n자동으로 인식해서 등록해줘요.\n(준비 중인 기능이에요)',
                'Take a photo of ingredients in your fridge\nand they\'ll be recognized automatically.\n(Coming soon)',
              ),
              buttonLabel: tr('사진 촬영하기', 'Take a photo'),
            ),
            _ComingSoonTab(
              icon: Icons.receipt_long_outlined,
              title: tr('영수증으로 한번에 등록', 'Register all at once from a receipt'),
              description: tr(
                '장 본 영수증을 스캔하면\n항목을 자동으로 인식해서 등록해줘요.\n(준비 중인 기능이에요)',
                'Scan your grocery receipt\nand items will be recognized automatically.\n(Coming soon)',
              ),
              buttonLabel: tr('영수증 촬영하기', 'Scan receipt'),
            ),
            const _FridgeScanTab(),
          ],
        ),
        bottomNavigationBar: _cart.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _cart),
                    child: Text(tr('냉장고에 담기 · ${_cart.length}개', 'Add to fridge · ${_cart.length}')),
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
      backgroundColor: const Color(0xFFFFFFFF),
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
              hintText: tr('재료 이름으로 검색', 'Search by ingredient name'),
              prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft),
              filled: true,
              fillColor: const Color(0xFFFFFFFF),
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
              ? Center(
                  child: Text(tr('검색 결과가 없어요', 'No results'), style: const TextStyle(color: AppColors.inkSoft)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, index) {
                    final entry = _filtered[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IngredientAvatar(name: entry.name, category: entry.category, size: 36),
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
                  decoration: InputDecoration(labelText: tr('수량', 'Quantity')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: InputDecoration(labelText: tr('단위', 'Unit')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(labelText: tr('유통기한', 'Expiry date')),
              child: Text(
                _expiryDate == null
                    ? tr('설정 안 함', 'Not set')
                    : '${_expiryDate!.year}.${_expiryDate!.month.toString().padLeft(2, '0')}.${_expiryDate!.day.toString().padLeft(2, '0')}',
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _confirm, child: Text(tr('담기', 'Add'))),
          ),
        ],
      ),
    );
  }
}

/// 냉장고 전체를 한 번에 촬영해서 담긴 재료를 자동으로 구분해주는 탭.
/// 사진 촬영/미리보기는 실제로 동작하지만, 재료 자동 인식은 이미지 인식 AI(비전 API) 연동이
/// 필요해 아직 준비 중이다 — 가짜 인식 결과를 보여주는 대신 정직하게 안내한다.
class _FridgeScanTab extends StatefulWidget {
  const _FridgeScanTab();

  @override
  State<_FridgeScanTab> createState() => _FridgeScanTabState();
}

class _FridgeScanTabState extends State<_FridgeScanTab> {
  XFile? _photo;
  bool _analyzing = false;

  Future<void> _openPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
              title: Text(tr('카메라로 냉장고 촬영', 'Take a photo of the fridge')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.green),
              title: Text(tr('갤러리에서 선택', 'Choose from gallery')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 90);
      if (picked != null && mounted) setState(() => _photo = picked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('사진을 가져오지 못했어요', 'Could not load photo'))),
        );
      }
    }
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _analyzing = false);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('재료 인식은 아직 준비 중이에요', 'Ingredient recognition is coming soon')),
        content: Text(
          tr(
            '사진은 잘 담았어요! 다만 재료를 자동으로 구분하려면\n'
            '실제 이미지 인식 AI(비전 API) 연동이 필요해서\n'
            '지금은 검색 탭에서 직접 등록해주셔야 해요.',
            'Your photo was saved! But automatically sorting ingredients\n'
            'needs a real image-recognition AI (vision API) integration,\n'
            'so for now please add items manually in the Search tab.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('확인', 'OK')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              DefaultTabController.of(context).animateTo(0);
            },
            child: Text(tr('검색 탭으로 이동', 'Go to Search tab')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photo == null) {
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
                child: const Icon(Icons.kitchen_outlined, size: 32, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              Text(
                tr('냉장고 통째로 촬영하기', 'Photograph the whole fridge'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  '냉장고 문을 연 채로 한 장 찍으면\n안에 있는 재료를 한 번에 찾아볼 수 있어요.',
                  'Take one photo with the fridge door open\nto find everything inside at once.',
                ),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _openPhotoSourceSheet,
                child: Text(tr('냉장고 촬영하기', 'Take a photo')),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(_photo!.path), width: double.infinity, height: 260, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _openPhotoSourceSheet,
                child: Text(tr('다시 찍기', 'Retake')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _analyzing ? null : _analyze,
                child: _analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(tr('재료 인식하기', 'Recognize ingredients')),
              ),
            ),
          ],
        ),
      ],
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
                  SnackBar(content: Text(tr('빠른 시일 내에 만나볼 수 있어요!', 'Coming soon!'))),
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
