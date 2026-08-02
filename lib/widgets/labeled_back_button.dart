import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// 뒤로가기 아이콘 옆에 작은 "뒤로가기" 설명 텍스트를 붙인 AppBar용 leading 위젯.
/// 주변 UI와 튀지 않도록 inkSoft 톤의 작은 글씨를 쓴다.
/// AppBar에서 쓸 때는 기본 leading 폭(56)보다 넓으므로 `leadingWidth: 96`도 함께 지정해야 한다.
class LabeledBackButton extends StatelessWidget {
  final Color? color;
  const LabeledBackButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.inkSoft;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).maybePop(),
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 20, color: resolvedColor),
            const SizedBox(width: 3),
            Text(
              tr('뒤로가기', 'Back'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: resolvedColor),
            ),
          ],
        ),
      ),
    );
  }
}
