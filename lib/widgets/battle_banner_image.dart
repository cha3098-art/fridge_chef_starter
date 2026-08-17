import 'package:flutter/material.dart';

/// 요리 대결 배너로 순환 적용하는 5종 고화질 3D VS 이미지 — 배틀 게시글 순서(리스트
/// 인덱스)에 따라 1→5→1... 순서로 반복된다.
const battleBannerImages = <String>[
  'assets/images/battle/battle_vs_1.jpg',
  'assets/images/battle/battle_vs_2.jpg',
  'assets/images/battle/battle_vs_3.jpg',
  'assets/images/battle/battle_vs_4.jpg',
  'assets/images/battle/battle_vs_5.jpg',
];

/// index % 5로 5종 배너 중 하나를 골라 꽉 찬 폭(cover)으로 보여준다.
/// 목록 카드와 상세 화면이 같은 배틀에 대해 같은 이미지를 보여주도록, 목록에서 쓰인
/// index를 상세 화면까지 그대로 전달해서 쓴다.
class BattleBannerImage extends StatelessWidget {
  final int index;
  final double height;
  final double borderRadius;

  const BattleBannerImage({
    super.key,
    required this.index,
    this.height = 165,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final image = battleBannerImages[index % battleBannerImages.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        image,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}
