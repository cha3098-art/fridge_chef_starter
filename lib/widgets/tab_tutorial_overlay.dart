import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// 하단 탭 5개(메인/냉장고관리/요리하기/푸드대결/소통공간) 각 화면에 처음 들어왔을 때
/// 한 번만 뜨는 코치마크 튜토리얼. 화면마다 GlobalKey로 특정 위젯을 오려내는 진짜
/// 스포트라이트 대신, 반투명 암전 + 중앙 안내 카드라는 단순한 형태를 택했다 — 화면 5개를
/// 전부 GlobalKey로 배선하는 건 리스크 대비 이득이 작고, 이 카드도 앱 전체가 이미 쓰는
/// 바텀시트 카드와 같은 톤(흰 배경/radius16/틸 포인트 버튼)이라 디자인에서 튀지 않는다.
/// 기존에 화면에 상시 떠 있는 안내 배너(예: 메인의 "영수증만 찍으면...")는 이 튜토리얼과
/// 별개로 그대로 둔다 — 이건 최초 1회용, 배너는 재방문자에게도 계속 보이는 상시 안내다.
class TabTutorialOverlay {
  static Future<void> showIfNeeded(
    BuildContext context, {
    required String prefsKey,
    required String title,
    required List<String> bodyLines,
    String? imageAsset,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKey) ?? false) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _TutorialCard(
        prefsKey: prefsKey,
        title: title,
        bodyLines: bodyLines,
        imageAsset: imageAsset,
      ),
    );
  }
}

class _TutorialCard extends StatefulWidget {
  final String prefsKey;
  final String title;
  final List<String> bodyLines;
  final String? imageAsset;

  const _TutorialCard({
    required this.prefsKey,
    required this.title,
    required this.bodyLines,
    this.imageAsset,
  });

  @override
  State<_TutorialCard> createState() => _TutorialCardState();
}

class _TutorialCardState extends State<_TutorialCard> {
  bool _dontShowAgain = false;

  Future<void> _close() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(widget.prefsKey, true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이미지+제목+본문은 길어질 수 있으니(문구가 길거나 작은 화면일 때) 이 구간만
            // 스크롤 가능하게 하고, "다시 보지 않기"/"확인" 줄은 화면 밖으로 안 밀려나게
            // 항상 하단에 고정한다.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 실제 화면을 잘라 어떤 버튼을 눌러야 하는지 보여주는 스크린샷 —
                    // 텍스트만으로는 "뭘 할 수 있는지"는 알아도 "어디를 눌러야 하는지"가
                    // 안 와닿는다는 피드백 반영.
                    if (widget.imageAsset != null)
                      Image.asset(widget.imageAsset!, fit: BoxFit.cover),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (final line in widget.bodyLines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Icon(Icons.circle,
                                        size: 5, color: AppColors.tealPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF334155),
                                          height: 1.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () =>
                          setState(() => _dontShowAgain = !_dontShowAgain),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _dontShowAgain,
                              activeColor: AppColors.tealPrimary,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (v) =>
                                  setState(() => _dontShowAgain = v ?? false),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                tr('다시 보지 않기', "Don't show again"),
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _close,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(tr('확인', 'Got it'),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
