import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fridge_mascot.dart';

/// Image.network/Image.asset의 errorBuilder에 그대로 꽂아 쓰는 공용 실패 대체 화면.
/// 사진 로드에 실패하면 라운딩된 박스 안에 냉장고 마스코트를 보여준다.
class RoundedMascotFallback extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  const RoundedMascotFallback({
    super.key,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.backgroundColor = AppColors.paperDeep,
  });

  @override
  Widget build(BuildContext context) {
    final mascotSize = switch ((width, height)) {
      (final w?, final h?) => (w < h ? w : h) * 0.5,
      (final w?, null) => w * 0.5,
      (null, final h?) => h * 0.5,
      _ => 40.0,
    };
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: FridgeMascot(size: mascotSize.clamp(24, 96).toDouble()),
    );
  }
}
