import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ingredient_catalog.dart';
import '../l10n/recipe_i18n.dart';
import '../l10n/tr.dart';
import '../models/fridge_item.dart';
import '../models/fridge_photo_analysis.dart';
import '../services/chef_points_store.dart';
import '../services/fridge_photo_recognition_service.dart';
import '../services/fridge_store.dart';
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
  /// true면 상위 카테고리 화면(세그먼트 탭)에 본문만 끼워 넣는 모드 — 자체 Scaffold/AppBar/
  /// MainReturnButton 없이 내부 캡슐탭+본문만 반환하고, "담기"는 Navigator.pop 대신
  /// FridgeStore에 바로 반영한 뒤 같은 화면에 머문다.
  final bool embed;

  const AddIngredientScreen(
      {super.key, this.initialTabIndex = 0, this.embed = false});

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final List<FridgeItem> _cart = [];

  void _addToCart(FridgeItem item) => setState(() => _cart.add(item));

  void _removeFromCart(int index) => setState(() => _cart.removeAt(index));

  Future<void> _confirmCart() async {
    if (!widget.embed) {
      Navigator.pop(context, _cart);
      return;
    }
    final count = _cart.length;
    final ok = await FridgeStore.instance.addItems(List.of(_cart));
    if (!mounted) return;
    if (!ok) {
      // 실패하면 장바구니를 비우지 않는다 — 사용자가 다시 "냉장고에 담기"를 눌러 재시도할 수 있게.
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
    setState(() => _cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('$count개 재료를 냉장고에 담았어요', 'Added $count items to your fridge'))),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      children: [
        _SearchTab(cart: _cart, onAdd: _addToCart, onRemove: _removeFromCart),
        _DirectInputTab(onAdd: _addToCart),
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
    );
  }

  Widget _buildCartBar() {
    // embed 모드에선 이 바가 Scaffold의 bottomNavigationBar가 아니라 카테고리 화면의
    // MainBottomNav(65) 위에 얹히는 일반 형제 위젯이라, SafeArea만으론 그 65px을 못
    // 피한다 — extendBody로 본문이 그 뒤까지 꽉 차 있어서 안 챙기면 냉장고 담기 버튼이
    // 하단 탭바와 겹쳐 보인다.
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + (widget.embed ? 65 : 0)),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _confirmCart,
            child: Text(tr('냉장고에 담기 · ${_cart.length}개',
                'Add to fridge · ${_cart.length}')),
          ),
        ),
      ),
    );
  }

  static const _tabs = [
    '검색',
    '직접입력',
    '사진인식',
    '영수증스캔',
    '냉장고 전체촬영',
  ];
  static const _tabsEn = [
    'Search',
    'Manual',
    'Photo scan',
    'Receipt scan',
    'Whole fridge',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => DefaultTabController(
        length: 5,
        initialIndex: widget.initialTabIndex,
        child: widget.embed
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _CapsuleTabBar(
                      tabs: [for (var i = 0; i < _tabs.length; i++) tr(_tabs[i], _tabsEn[i])],
                    ),
                  ),
                  Expanded(child: _buildTabBarView()),
                  if (_cart.isNotEmpty) _buildCartBar(),
                ],
              )
            : Scaffold(
                backgroundColor: AppColors.paper,
                floatingActionButton: Padding(
                  padding: EdgeInsets.only(
                      bottom: 95 + MediaQuery.of(context).padding.bottom),
                  child: const MainReturnButton(),
                ),
                appBar: AppBar(
                  leading: const LabeledBackButton(),
                  leadingWidth: 96,
                  backgroundColor: AppColors.paper,
                  elevation: 0,
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
                        child: Text(tr('재료 등록', 'Add Ingredients'),
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
                        padding: EdgeInsets.only(right: 12),
                        child: LanguageToggle()),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(55),
                    child: _CapsuleTabBar(
                      tabs: [for (var i = 0; i < _tabs.length; i++) tr(_tabs[i], _tabsEn[i])],
                    ),
                  ),
                ),
                body: _buildTabBarView(),
                bottomNavigationBar: _cart.isEmpty ? null : _buildCartBar(),
              ),
      ),
    );
  }
}

/// 사진인식/영수증스캔 탭에서 "일치하는 재료를 찾지 못했어요" 안내와 함께 보여주는
/// 바로가기 버튼 — 탭마다 검색 탭을 직접 눌러 찾아가야 하는 번거로움을 없애고
/// DefaultTabController로 바로 "검색"(0번) 탭으로 이동시킨다.
class _GoToSearchTabButton extends StatelessWidget {
  const _GoToSearchTabButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => DefaultTabController.of(context).animateTo(0),
      icon: const Icon(Icons.search, size: 18),
      label: Text(tr('검색 탭으로 이동', 'Go to Search tab')),
    );
  }
}

/// 사진인식/영수증스캔 탭 하단에 항상 보이는 안내 — 가공식품/냉동식품 등 카탈로그에 없어
/// AI가 인식하지 못하는 품목이 있을 때, "직접입력"(1번) 탭으로 바로 넘어갈 수 있게 한다.
class _ManualEntryHint extends StatelessWidget {
  const _ManualEntryHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            tr('원하는 재료가 인식되지 않나요? 직접 타이핑해서 등록할 수 있어요.',
                "Can't find the ingredient you want? You can type it in manually."),
            style: const TextStyle(
                fontSize: 12, color: AppColors.inkSoft, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => DefaultTabController.of(context).animateTo(1),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(tr('직접 입력하러 가기', 'Go to manual entry')),
          ),
        ],
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
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
  StorageLocation _storageLocation = StorageLocation.fridge;
  late String _storageCategory;

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
    _storageCategory = defaultStorageCategory(widget.entry.category);
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
        storageLocation: _storageLocation,
        storageCategory: _storageCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
          const SizedBox(height: 16),
          _StorageLocationToggle(
            value: _storageLocation,
            onChanged: (v) => setState(() => _storageLocation = v),
          ),
          const SizedBox(height: 12),
          _StorageCategoryPicker(
            value: _storageCategory,
            onChanged: (v) => setState(() => _storageCategory = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _confirm, child: Text(tr('담기', 'Add'))),
          ),
        ],
        ),
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
              const _ManualEntryHint(),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
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
                child: Column(
                  children: [
                    Text(
                      tr('일치하는 재료를 찾지 못했어요. 검색 탭에서 직접 등록해주세요.',
                          "Couldn't find matching items. Please add them manually in the Search tab."),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.inkSoft, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const _GoToSearchTabButton(),
                  ],
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
        const _ManualEntryHint(),
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
              const _ManualEntryHint(),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
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
                child: Column(
                  children: [
                    Text(
                      tr('일치하는 재료를 찾지 못했어요. 검색 탭에서 직접 등록해주세요.',
                          "Couldn't find matching items. Please add them manually in the Search tab."),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.inkSoft, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const _GoToSearchTabButton(),
                  ],
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
        const _ManualEntryHint(),
      ],
    );
  }
}

/// 냉장고/냉동고 저장 위치를 고르는 2분할 세그먼트 버튼 — 검색 탭 수량 시트, 직접입력 탭이 공유한다.
class _StorageLocationToggle extends StatelessWidget {
  final StorageLocation value;
  final ValueChanged<StorageLocation> onChanged;

  const _StorageLocationToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: tr('저장 위치', 'Storage location')),
      child: Row(
        children: StorageLocation.values.map((loc) {
          final selected = loc == value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: loc == StorageLocation.values.first ? 8 : 0),
              child: GestureDetector(
                onTap: () => onChanged(loc),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : AppColors.paperDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? AppColors.ink : AppColors.cardBorder),
                  ),
                  child: Text(
                    loc.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 세부 분류(육류/유제품/야채/생선/밑반찬/소스/기타) 칩 선택 — 검색 탭 수량 시트, 직접입력 탭이 공유한다.
class _StorageCategoryPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _StorageCategoryPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: tr('세부 분류', 'Category')),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: storageCategories.map((c) {
          final selected = c == value;
          return ChoiceChip(
            label: Text(trTag(c)),
            selected: selected,
            onSelected: (_) => onChanged(c),
            selectedColor: AppColors.ink,
            backgroundColor: AppColors.paperDeep,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
            side: BorderSide(color: selected ? AppColors.ink : AppColors.cardBorder),
          );
        }).toList(),
      ),
    );
  }
}

/// "직접입력" 탭 — 재료 카탈로그에 없는 항목(예: 특이 재료, 밑반찬, 소스류)을 이름/카테고리/
/// 저장위치/수량/유통기한까지 직접 입력해서 등록한다. FridgeStore.addItems가 카탈로그에 없는
/// 이름을 만나면 ingredients 마스터에 새 행을 자동 생성하므로, 여기서는 폼만 채우면 된다.
class _DirectInputTab extends StatefulWidget {
  final ValueChanged<FridgeItem> onAdd;

  const _DirectInputTab({required this.onAdd});

  @override
  State<_DirectInputTab> createState() => _DirectInputTabState();
}

/// 직접입력 폼 한 세트(재료명/수량/단위/유통기한/저장위치/세부분류)의 상태.
/// "+ 항목 추가"를 누를 때마다 하나씩 생겨서, 여러 재료를 한 화면에서 동시에 입력할 수 있게 한다.
/// 화면엔 세부분류(storageCategory, 야채/생선 등) 하나만 노출하고, ingredients 마스터 행에
/// 넣을 카탈로그 category('채소'/'수산' 등)는 catalogCategoryForStorage로 내부에서만 역매핑한다
/// — 카탈로그 category를 사용자가 직접 고르게 하면 같은 화면에 "채소"와 "야채"가 동시에
/// 보여서 헷갈린다는 피드백이 있었다.
class _DirectInputRowData {
  final nameController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final unitController = TextEditingController(text: '개');
  StorageLocation storageLocation = StorageLocation.fridge;
  String storageCategory = '기타';
  DateTime? expiryDate;

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    unitController.dispose();
  }
}

class _DirectInputTabState extends State<_DirectInputTab> {
  final List<_DirectInputRowData> _rows = [_DirectInputRowData()];

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(_DirectInputRowData row) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: row.expiryDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => row.expiryDate = picked);
  }

  void _addRow() => setState(() => _rows.add(_DirectInputRowData()));

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  void _submitAll() {
    final itemsToAdd = <FridgeItem>[];
    final skippedRows = <int>[];
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final name = row.nameController.text.trim();
      if (name.isEmpty) {
        skippedRows.add(i);
        continue;
      }
      final qty = double.tryParse(row.qtyController.text) ?? 1;
      final unit = row.unitController.text.trim();
      itemsToAdd.add(FridgeItem(
        name: name,
        quantity: qty,
        unit: unit.isEmpty ? '개' : unit,
        expiryDate: row.expiryDate,
        category: catalogCategoryForStorage(row.storageCategory),
        storageLocation: row.storageLocation,
        storageCategory: row.storageCategory,
      ));
    }
    if (itemsToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('재료 이름을 입력해주세요', 'Please enter a name'))),
      );
      return;
    }
    for (final item in itemsToAdd) {
      widget.onAdd(item);
    }
    final count = itemsToAdd.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(tr('$count개 재료를 담았어요', 'Added $count items'))),
    );
    setState(() {
      for (final row in _rows) {
        row.dispose();
      }
      _rows
        ..clear()
        ..add(_DirectInputRowData());
    });
  }

  Widget _buildRow(int index) {
    final row = _rows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('재료 ${index + 1}', 'Item ${index + 1}'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkSoft),
              ),
              if (_rows.length > 1)
                GestureDetector(
                  onTap: () => _removeRow(index),
                  child: const Icon(Icons.close,
                      size: 20, color: AppColors.inkSoft),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.nameController,
            style: const TextStyle(color: AppColors.ink),
            decoration:
                InputDecoration(labelText: tr('재료 이름', 'Ingredient name')),
            onChanged: (_) => setState(() {}),
          ),
          _NameSuggestionChips(
            query: row.nameController.text.trim(),
            onPick: (entry) {
              setState(() {
                row.nameController.text = entry.name;
                row.storageCategory = defaultStorageCategory(entry.category);
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.qtyController,
                  style: const TextStyle(color: AppColors.ink),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('수량', 'Quantity')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: row.unitController,
                  style: const TextStyle(color: AppColors.ink),
                  decoration: InputDecoration(labelText: tr('단위', 'Unit')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _pickDate(row),
            child: InputDecorator(
              decoration:
                  InputDecoration(labelText: tr('유통기한', 'Expiry date')),
              child: Text(
                row.expiryDate == null
                    ? tr('설정 안 함', 'Not set')
                    : '${row.expiryDate!.year}.${row.expiryDate!.month.toString().padLeft(2, '0')}.${row.expiryDate!.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.ink),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StorageLocationToggle(
            value: row.storageLocation,
            onChanged: (v) => setState(() => row.storageLocation = v),
          ),
          const SizedBox(height: 12),
          _StorageCategoryPicker(
            value: row.storageCategory,
            onChanged: (v) => setState(() => row.storageCategory = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 130),
      children: [
        for (var i = 0; i < _rows.length; i++) _buildRow(i),
        OutlinedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add, size: 18),
          label: Text(tr('항목 추가', 'Add item')),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitAll,
            child: Text(tr(
                '${_rows.length}개 항목 한 번에 담기', 'Add ${_rows.length} items at once')),
          ),
        ),
      ],
    );
  }
}

/// 직접입력 "재료 이름" 필드 아래에 뜨는 카탈로그 매칭 자동완성 칩 — 검색 탭처럼
/// 타이핑 중인 이름으로 ingredientCatalog를 필터링해 최대 6개까지 보여주고, 탭하면
/// 이름을 채워주는 동시에 그 재료의 실제 세부분류로 자동 설정해준다.
class _NameSuggestionChips extends StatelessWidget {
  final String query;
  final ValueChanged<IngredientCatalogEntry> onPick;

  const _NameSuggestionChips({required this.query, required this.onPick});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();
    final matches = ingredientCatalog
        .where((e) => e.name.contains(query))
        .take(6)
        .toList();
    // 정확히 일치하는 재료 하나뿐이면 이미 다 골랐다는 뜻이라 칩을 숨긴다.
    if (matches.isEmpty ||
        (matches.length == 1 && matches.first.name == query)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: matches
            .map((entry) => ActionChip(
                  label: Text(trIngredientName(entry.name)),
                  labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                  backgroundColor: AppColors.paperDeep,
                  side: const BorderSide(color: AppColors.cardBorder),
                  onPressed: () => onPick(entry),
                ))
            .toList(),
      ),
    );
  }
}
