import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ingredient_catalog.dart';
import '../l10n/tr.dart';
import '../models/fridge_item.dart';
import '../services/locale_store.dart';
import '../services/ocr_parser_service.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/language_toggle.dart';

/// "재료 등록" 화면 — 검색 / 사진인식 / 영수증스캔 / 냉장고 전체촬영 네 가지 방법을 탭으로 제공
/// 검색 탭과 영수증스캔 탭은 실제로 동작하며, 담은 재료를 냉장고 화면으로 반환한다.
/// 사진인식·냉장고 전체촬영은 실제 이미지 인식 AI 백엔드가 아직 없어
/// (냉장고 전체촬영은 사진 촬영/미리보기까지는 실제로 동작하고) 인식 자체는 준비 중으로 안내한다.
///
/// 상단 탭은 언더라인 TabBar 대신 카카오톡 스타일의 캡슐형 필터 칩(_CapsuleTabBar)을 쓴다
/// — 선택된 탭만 진한 배경/흰 글씨로 강하게 도드라진다.
class AddIngredientScreen extends StatefulWidget {
  final int initialTabIndex;

  const AddIngredientScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final List<FridgeItem> _cart = [];

  void _addToCart(FridgeItem item) => setState(() => _cart.add(item));

  void _removeFromCart(int index) => setState(() => _cart.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => DefaultTabController(
        length: 4,
        initialIndex: widget.initialTabIndex,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(
            backgroundColor: AppColors.paper,
            elevation: 0,
            title: Text(tr('재료 등록', 'Add Ingredients')),
            actions: const [
              Padding(
                  padding: EdgeInsets.only(right: 12), child: LanguageToggle()),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(55),
              child: _CapsuleTabBar(
                tabs: [
                  tr('검색', 'Search'),
                  tr('사진인식', 'Photo scan'),
                  tr('영수증스캔', 'Receipt scan'),
                  tr('냉장고 전체촬영', 'Whole fridge'),
                ],
              ),
            ),
          ),
          body: TabBarView(
            children: [
              _SearchTab(
                  cart: _cart, onAdd: _addToCart, onRemove: _removeFromCart),
              _ComingSoonTab(
                icon: Icons.camera_alt_outlined,
                title: tr('사진으로 재료 인식', 'Recognize ingredients from a photo'),
                description: tr(
                  '냉장고 속 재료 사진을 찍으면\n자동으로 인식해서 등록해줘요.\n(준비 중인 기능이에요)',
                  'Take a photo of ingredients in your fridge\nand they\'ll be recognized automatically.\n(Coming soon)',
                ),
                buttonLabel: tr('사진 촬영하기', 'Take a photo'),
              ),
              _ReceiptScanTab(onAdd: _addToCart),
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
                      child: Text(tr('냉장고에 담기 · ${_cart.length}개',
                          'Add to fridge · ${_cart.length}')),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// 카카오톡 채팅 필터 스타일의 둥근 캡슐 탭 — DefaultTabController를 직접 구독해서
/// 선택된 탭만 진한 잉크색 배경/흰 글씨로 강조하고, 나머지는 옅은 회색 캡슐로 흐리게 보여준다.
class _CapsuleTabBar extends StatelessWidget {
  final List<String> tabs;

  const _CapsuleTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = controller.index == index;
                return GestureDetector(
                  onTap: () => controller.animateTo(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.ink : AppColors.paperDeep,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.ink : AppColors.cardBorder,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SearchTab extends StatefulWidget {
  final List<FridgeItem> cart;
  final ValueChanged<FridgeItem> onAdd;
  final ValueChanged<int> onRemove;

  const _SearchTab(
      {required this.cart, required this.onAdd, required this.onRemove});

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
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => _QuantitySheet(entry: entry),
    );
    if (result != null) widget.onAdd(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            style: const TextStyle(color: AppColors.ink),
            decoration: InputDecoration(
              hintText: tr('재료 이름으로 검색', 'Search by ingredient name'),
              prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft),
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
                        style:
                            const TextStyle(fontSize: 11, color: AppColors.ink),
                      ),
                      backgroundColor: AppColors.greenSoft,
                      deleteIcon: const Icon(Icons.close,
                          size: 14, color: AppColors.inkSoft),
                      onDeleted: () => widget.onRemove(i),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FridgeMascot(size: 84),
                      const SizedBox(height: AppSpacing.md),
                      Text(tr('검색 결과가 없어요', 'No results'),
                          style: const TextStyle(color: AppColors.inkSoft)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (context, index) {
                    final entry = _filtered[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IngredientPhoto(
                        photoUrl: entry.photoUrl,
                        name: entry.name,
                        category: entry.category,
                        size: 52,
                        showBorder: true,
                      ),
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          entry.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.ink,
                              letterSpacing: -0.3),
                        ),
                      ),
                      subtitle: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.paperDeep,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.category,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkSoft,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      trailing: Icon(Icons.add_circle_outline,
                          color: AppColors.green.withValues(alpha: 0.9),
                          size: 28),
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
    _expiryDate = shelfLife != null
        ? DateTime.now().add(Duration(days: shelfLife))
        : null;
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
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.entry.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.ink)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  style: const TextStyle(color: AppColors.ink),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('수량', 'Quantity')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  style: const TextStyle(color: AppColors.ink),
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
                style: const TextStyle(color: AppColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _confirm, child: Text(tr('담기', 'Add'))),
          ),
        ],
      ),
    );
  }
}

/// 영수증 사진을 찍으면 기기 내(On-device) OCR로 텍스트를 인식해서, 우리 재료 카탈로그와
/// 일치하는 항목만 골라 보여준다. 사용자가 체크박스로 확인/해제한 뒤 담으면
/// 검색 탭과 똑같은 cart 흐름(onAdd)을 타고 "냉장고에 담기" 버튼으로 최종 등록된다.
class _ReceiptScanTab extends StatefulWidget {
  final ValueChanged<FridgeItem> onAdd;

  const _ReceiptScanTab({required this.onAdd});

  @override
  State<_ReceiptScanTab> createState() => _ReceiptScanTabState();
}

class _ReceiptScanTabState extends State<_ReceiptScanTab> {
  File? _receiptImage;
  List<FridgeItem> _parsedItems = [];
  List<bool> _selected = [];
  bool _isProcessing = false;
  bool _addedToCart = false;

  Future<void> _openPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.green),
              title: Text(tr('영수증 촬영하기', 'Take a photo of the receipt')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.green),
              title: Text(tr('갤러리에서 선택', 'Choose from gallery')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 2000, imageQuality: 90);
      if (picked == null || !mounted) return;

      final file = File(picked.path);
      setState(() {
        _receiptImage = file;
        _isProcessing = true;
        _parsedItems = [];
        _selected = [];
        _addedToCart = false;
      });

      final results = await OcrParserService.instance.parseReceipt(file);
      if (!mounted) return;
      setState(() {
        _parsedItems = results;
        _selected = List.filled(results.length, true);
        _isProcessing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(tr('영수증을 분석하지 못했어요', 'Could not analyze the receipt'))),
      );
    }
  }

  void _addSelectedToCart() {
    var count = 0;
    for (var i = 0; i < _parsedItems.length; i++) {
      if (_selected[i]) {
        widget.onAdd(_parsedItems[i]);
        count++;
      }
    }
    if (count == 0) return;
    setState(() => _addedToCart = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('$count개 재료를 담았어요', 'Added $count items'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_receiptImage == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: AppColors.paperDeep, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_outlined,
                    size: 32, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              Text(
                tr('영수증으로 한번에 등록', 'Register all at once from a receipt'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  '장 본 영수증을 찍으면\n우리 재료 목록에 있는 항목을 찾아드려요.',
                  'Take a photo of your grocery receipt\nand we\'ll find matching items in our catalog.',
                ),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _openPhotoSourceSheet,
                child: Text(tr('영수증 촬영하기', 'Scan receipt')),
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
          child: Image.file(_receiptImage!,
              width: double.infinity, height: 200, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.green)),
          )
        else ...[
          if (_parsedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  tr('일치하는 재료를 찾지 못했어요. 검색 탭에서 직접 등록해주세요.',
                      "Couldn't find matching items. Please add them manually in the Search tab."),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.inkSoft, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            Text(
              tr('인식된 재료 ${_parsedItems.length}개',
                  '${_parsedItems.length} items found'),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _parsedItems.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.green,
                secondary: IngredientAvatar(
                    name: _parsedItems[i].name,
                    category: _parsedItems[i].category,
                    size: 36),
                title: Text(_parsedItems[i].name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink)),
                subtitle: Text(
                  _parsedItems[i].expiryDate == null
                      ? tr('유통기한 미설정', 'No expiry set')
                      : tr(
                          '예상 유통기한: ${_parsedItems[i].expiryDate!.year}.${_parsedItems[i].expiryDate!.month.toString().padLeft(2, '0')}.${_parsedItems[i].expiryDate!.day.toString().padLeft(2, '0')}',
                          'Est. expiry: ${_parsedItems[i].expiryDate!.year}.${_parsedItems[i].expiryDate!.month.toString().padLeft(2, '0')}.${_parsedItems[i].expiryDate!.day.toString().padLeft(2, '0')}',
                        ),
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
                value: _selected[i],
                onChanged: (v) => setState(() => _selected[i] = v ?? false),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addedToCart ? null : _addSelectedToCart,
                child: Text(_addedToCart
                    ? tr('담았어요', 'Added')
                    : tr('선택한 재료 담기', 'Add selected items')),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _openPhotoSourceSheet,
            child: Text(tr('영수증 다시 찍기', 'Retake photo')),
          ),
        ],
      ],
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.green),
              title: Text(tr('카메라로 냉장고 촬영', 'Take a photo of the fridge')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.green),
              title: Text(tr('갤러리에서 선택', 'Choose from gallery')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 2000, imageQuality: 90);
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
        title: Text(
            tr('재료 인식은 아직 준비 중이에요', 'Ingredient recognition is coming soon')),
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
                decoration: const BoxDecoration(
                    color: AppColors.paperDeep, shape: BoxShape.circle),
                child: const Icon(Icons.kitchen_outlined,
                    size: 32, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              Text(
                tr('냉장고 통째로 촬영하기', 'Photograph the whole fridge'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  '냉장고 문을 연 채로 한 장 찍으면\n안에 있는 재료를 한 번에 찾아볼 수 있어요.',
                  'Take one photo with the fridge door open\nto find everything inside at once.',
                ),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft, height: 1.5),
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
          child: Image.file(File(_photo!.path),
              width: double.infinity, height: 260, fit: BoxFit.cover),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
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
              decoration: const BoxDecoration(
                  color: AppColors.paperDeep, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSoft, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(tr('빠른 시일 내에 만나볼 수 있어요!', 'Coming soon!'))),
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
