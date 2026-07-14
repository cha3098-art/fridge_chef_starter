import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 순정 이미지/일러스트 에셋 없이 코드로 그리는 냉장고 마스코트.
/// 로그인/빈 상태 등 화면에 온기를 더하는 용도로 쓴다.
class FridgeMascot extends StatelessWidget {
  final double size;
  final Color bodyColor;
  final Color doorColor;

  const FridgeMascot({
    super.key,
    this.size = 96,
    this.bodyColor = AppColors.green,
    this.doorColor = AppColors.greenSoft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // 위로 살짝 삐져나온 잎사귀 장식 — 신선함을 상징
          Positioned(
            top: -size * 0.12,
            child: Icon(Icons.eco, color: AppColors.greenDeep, size: size * 0.22),
          ),
          Padding(
            padding: EdgeInsets.only(top: size * 0.1),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bodyColor,
                borderRadius: BorderRadius.circular(size * 0.22),
                boxShadow: AppColors.cardShadow,
              ),
              padding: EdgeInsets.all(size * 0.08),
              child: Column(
                children: [
                  // 윗칸 도어 — 표정이 들어간다
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: doorColor,
                        borderRadius: BorderRadius.circular(size * 0.14),
                      ),
                      child: const CustomPaint(painter: _FacePainter(color: AppColors.greenDeep)),
                    ),
                  ),
                  SizedBox(height: size * 0.05),
                  // 아랫칸 도어
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: doorColor,
                        borderRadius: BorderRadius.circular(size * 0.14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final Color color;
  const _FacePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.08
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = color;

    final eyeY = size.height * 0.42;
    final eyeDx = size.width * 0.22;
    final eyeRadius = size.shortestSide * 0.055;
    canvas.drawCircle(Offset(size.width / 2 - eyeDx, eyeY), eyeRadius, fillPaint);
    canvas.drawCircle(Offset(size.width / 2 + eyeDx, eyeY), eyeRadius, fillPaint);

    final mouthRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.5),
      width: size.width * 0.28,
      height: size.height * 0.3,
    );
    canvas.drawArc(mouthRect, 0.25, 2.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) => oldDelegate.color != color;
}
