import 'package:flutter/material.dart';

import '../theme/food_visuals.dart';

/// 요리자랑 상세화면 전용 — 업로드해주신 장식 액자 이미지를 카드의 전체 틀로 쓰고,
/// 액자의 투명한 내경 창 안에 따뜻한 크림 톤 캔버스를 깔아 그 위에 폴라로이드 느낌의
/// 사진(흰 테두리 + 소프트 그림자)을 올린다.
/// 제목/본문/작성시간은 이 위젯 밖, 액자 아래의 별도 카드 패널에 둔다(호출부에서 처리).
class FramedPostCard extends StatelessWidget {
  final String frameCategory;
  final Widget photo;
  final VoidCallback? onPhotoTap;

  const FramedPostCard({
    super.key,
    required this.frameCategory,
    required this.photo,
    this.onPhotoTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 액자 테두리/하단 장식 스트립을 확실히 피하도록 카드 크기 비율로 여백을 잡는다.
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final insetTop = h * 0.16;
          final insetSide = w * 0.16;
          final insetBottom = h * 0.32;

          return Stack(
            children: [
              // 1 레이어 — 액자 내경 창 = 크림 톤 캔버스 배경
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                      top: insetTop,
                      left: insetSide,
                      right: insetSide,
                      bottom: insetBottom),
                  child: Container(
                    color: const Color(0xFFFDFBF7),
                    alignment: Alignment.center,
                    // 2 — 폴라로이드 느낌 사진: 흰 테두리 + 소프트 그림자
                    child: FractionallySizedBox(
                      widthFactor: 0.82,
                      heightFactor: 0.82,
                      child: GestureDetector(
                        onTap: onPhotoTap,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: photo,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 3 레이어 — 선택된 테마 액자 이미지 (맨 위)
              Positioned.fill(
                child: Image.asset(bragFrameAsset(frameCategory),
                    fit: BoxFit.cover),
              ),
            ],
          );
        },
      ),
    );
  }
}
