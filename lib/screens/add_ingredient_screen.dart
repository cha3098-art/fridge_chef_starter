import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ingredient_catalog.dart';
import '../l10n/recipe_i18n.dart';
import '../l10n/tr.dart';
import '../models/fridge_item.dart';
import '../models/fridge_photo_analysis.dart';
import '../services/fridge_photo_recognition_service.dart';
import '../services/locale_store.dart';
import '../services/ocr_parser_service.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/main_return_button.dart';

/// "재료 등록" 화면 — 검색 / 사진인식 / 영수증스캔 / 냉장고 전체촬영 네 가지 방법을 탭으로 제공.
/// 네 탭 모두 실제로 동작하며, 담은 재료를 냉장고 화면으로 반환한다.
/// 사진인식·냉장고 전체촬영은 GPT-4o-mini Vision(analyze-fridge-photo Edge Function)으로
/// 실제 이미지 인식을 수행한다 — 카메라로 재료 한두 개를 가까이 찍느냐(사진인식) 냉장고
/// 문을 연 채로 전체를 찍느냐(전체촬영)의 차이일 뿐 흐름이 같아 _PhotoRecognitionTab을 공유한다.
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
          floatingActionButton: const MainReturnButton(),
          appBar: AppBar(
            leading: const LabeledBackButton(),
            leadingWidth: 96,
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
              _PhotoRecognitionTab(
                icon: Icons.camera_alt_outlined,
                title: tr('사진으로 재료 인식', 'Recognize ingredients from a photo'),
                description: tr(
                  '재료를 가까이서 찍으면\nAI가 자동으로 인식해서 등록해줘요.',
                  'Take a close-up photo of an ingredient\nand AI will recognize it automatically.',
                ),
                buttonLabel: tr('사진 촬영하기', 'Take a photo'),
                onAdd: _addToCart,
              ),
              _ReceiptScanTab(onAdd: _addToCart),
              _PhotoRecognitionTab(
                icon: Icons.kitchen_outlined,
                title: tr('냉장고 통째로 촬영하기', 'Photograph the whole fridge'),
                description: tr(
                  '냉장고 문을 연 채로 한 장 찍으면\nAI가 안에 있는 재료를 한 번에 찾아드려요.',
                  'Take one photo with the fridge door open\nand AI will find everything inside at once.',
                ),
                buttonLabel: tr('냉장고 촬영하기', 'Take a photo'),
                onAdd: _addToCart,
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
                        '${trIngredientName(widget.cart[i].name)} ${widget.cart[i].quantityLabel}',
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
                          trIngredientName(entry.name),
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
                            trTag(entry.category),
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
    _unitController =
        TextEditingController(text: localizedFridgeUnit(widget.entry.unitDefault));
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
    final unit = canonicalFridgeUnit(_unitController.text.trim());
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
          Text(trIngredientName(widget.entry.name),
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
          const SizedBox(height: 6),
          Text(
            tr(
                '포장지에 적힌 유통기한(또는 소비기한)을 눌러서 선택해주세요. 이 날짜를 기준으로 '
                '냉장고 화면의 D-Day와 유통기한 임박 알림이 계산돼요.',
                'Tap to select the expiry (or use-by) date printed on the package. '
                    "It's what drives the D-Day badge and expiry alerts on the Fridge screen."),
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.inkSoft, height: 1.4),
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
                title: Text(trIngredientName(_parsedItems[i].name),
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

/// "사진인식"과 "냉장고 전체촬영" 탭이 공유하는 위젯 — 촬영 대상이 재료 한두 개냐
/// 냉장고 전체냐의 차이일 뿐, 사진 촬영 → analyze-fridge-photo Edge Function(GPT-4o-mini
/// Vision) 호출 → 카탈로그 매칭 결과 체크박스 → 담기 흐름은 완전히 동일하다.
///
/// OCR 영수증 스캔과 같은 원칙: AI가 인식했어도 우리 재료 카탈로그에 없는 이름은 등록할 수
/// 없으므로(FridgeStore.addItems가 조용히 스킵) matched만 체크박스로 보여주고, 카탈로그
/// 밖에서 인식된 이름은 "이런 것도 보였지만 아직 등록할 수 없어요"로 정직하게 따로 알린다.
class _PhotoRecognitionTab extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final ValueChanged<FridgeItem> onAdd;

  const _PhotoRecognitionTab({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onAdd,
  });

  @override
  State<_PhotoRecognitionTab> createState() => _PhotoRecognitionTabState();
}

class _PhotoRecognitionTabState extends State<_PhotoRecognitionTab> {
  File? _photo;
  bool _analyzing = false;
  FridgePhotoAnalysis? _analysis;
  List<bool> _selected = [];
  bool _addedToCart = false;
  String? _errorMessage;

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
              title: Text(tr('카메라로 촬영', 'Take a photo')),
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
        _photo = file;
        _analysis = null;
        _selected = [];
        _addedToCart = false;
        _errorMessage = null;
      });
      await _analyze(file);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('사진을 가져오지 못했어요', 'Could not load photo'))),
        );
      }
    }
  }

  Future<void> _analyze(File file) async {
    setState(() {
      _analyzing = true;
      _errorMessage = null;
    });
    try {
      final result = await FridgePhotoRecognitionService.instance.analyze(file);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _selected = List.filled(result.matched.length, true);
        _analyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _addSelectedToCart() {
    final analysis = _analysis;
    if (analysis == null) return;
    var count = 0;
    for (var i = 0; i < analysis.matched.length; i++) {
      if (_selected[i]) {
        widget.onAdd(analysis.matched[i].toFridgeItem());
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
                child: Icon(widget.icon, size: 32, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkSoft, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _openPhotoSourceSheet,
                child: Text(widget.buttonLabel),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = _analysis;
    final unmatchedRaw = analysis == null
        ? const <String>[]
        : analysis.recognizedRaw
            .where((name) => !analysis.matched.any((m) => m.name == name))
            .map(trIngredientName)
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_photo!,
              width: double.infinity, height: 220, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        if (_analyzing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.green)),
          )
        else if (_errorMessage != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                tr('재료 인식에 실패했어요: $_errorMessage',
                    'Could not recognize ingredients: $_errorMessage'),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.red, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _analyze(_photo!),
            child: Text(tr('다시 시도', 'Try again')),
          ),
        ] else if (analysis != null) ...[
          if (analysis.matched.isEmpty)
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
              tr('인식된 재료 ${analysis.matched.length}개',
                  '${analysis.matched.length} items found'),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < analysis.matched.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.green,
                secondary: IngredientAvatar(
                    name: analysis.matched[i].name,
                    category: analysis.matched[i].category,
                    size: 36),
                title: Text(trIngredientName(analysis.matched[i].name),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.ink)),
                subtitle: Text(
                  analysis.matched[i].defaultShelfLifeDays == null
                      ? tr('유통기한 미설정', 'No expiry set')
                      : tr(
                          '예상 보관기한: ${analysis.matched[i].defaultShelfLifeDays}일',
                          'Est. shelf life: ${analysis.matched[i].defaultShelfLifeDays} days'),
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
          if (unmatchedRaw.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tr(
                  '이런 것도 보였지만 아직 등록할 수 없어요: ${unmatchedRaw.join(', ')}',
                  "Also spotted, but can't be added yet: ${unmatchedRaw.join(', ')}",
                ),
                style: const TextStyle(fontSize: 11, color: AppColors.gold),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _openPhotoSourceSheet,
            child: Text(tr('다시 찍기', 'Retake photo')),
          ),
        ],
      ],
    );
  }
}
