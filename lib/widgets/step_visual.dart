import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fridge_mascot.dart';

/// 조리 단계별 '비주얼 스텝 카드'.
/// 우선순위: ① 레시피 전용 단계 이미지(imageAsset, MS Copilot/Bing Image Creator로 무료
/// 생성해 assets/images/steps/에 넣어둔 것) ② 그 레시피의 대표 완성 사진(recipePhotoUrl)
/// ③ 냉장고 셰프 마스코트 가이드 일러스트. 조리 단계 텍스트와 무관한 임의의 사진/아이콘은
/// 절대 보여주지 않는다 — 매칭되는 진짜 이미지가 없으면 마스코트로 정직하게 대체한다.
class StepVisual extends StatelessWidget {
  final String? imageAsset;
  final String? recipePhotoUrl;
  final String stepDescription;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const StepVisual({
    super.key,
    required this.imageAsset,
    required this.stepDescription,
    this.recipePhotoUrl,
    this.width = double.infinity,
    this.height = 180,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  Widget _mascotGuide() {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.greenSoft, AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FridgeMascot(size: height * 0.38),
          const SizedBox(height: 6),
          const Text(
            '냉장고 셰프 레시피 가이드',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.greenDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipePhoto() {
    final url = recipePhotoUrl;
    if (url == null || url.isEmpty) return _mascotGuide();
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _mascotGuide(),
        errorBuilder: (context, error, stack) => _mascotGuide(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = imageAsset;
    if (asset == null || asset.isEmpty) return _recipePhoto();

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _recipePhoto(),
      ),
    );
  }
}
