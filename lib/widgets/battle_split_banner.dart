import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_theme.dart';
import '../theme/battle_avatars.dart';

/// 배틀 목록/상세 화면이 공유하는 대각선 스플릿 마스코트 배너 — 두 참가자 이미지를
/// "/" 모양 슬래시로 잘라 붙이고, 그 이음매 위에 화이트 보더+섀도우가 적용된 볼드
/// ⚔️ VS 배지를 겹쳐 보여준다. 상대가 아직 없는 자리는 대기 실루엣으로 표시한다.
class BattleSplitBanner extends StatelessWidget {
  final String hostUserId;
  final String? hostGender;
  final String? challengerUserId;
  final String? challengerGender;
  final double height;
  final double borderRadius;

  const BattleSplitBanner({
    super.key,
    required this.hostUserId,
    this.hostGender,
    this.challengerUserId,
    this.challengerGender,
    this.height = 150,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // 이미지가 배너 전체 폭 기준으로 가운데 정렬되면 대각선이 얼굴 한가운데를
            // 갈라버린다 — host는 왼쪽 절반 쪽으로, 상대는 오른쪽 절반 쪽으로
            // alignX를 밀어서 각자 자기 영역 안에 얼굴 전체가 들어오게 한다.
            Positioned.fill(
              child: ClipPath(
                clipper: const _SlashClipper(rightSide: false),
                child: _BattleThumb(
                    userId: hostUserId,
                    gender: hostGender,
                    alignX: -0.55,
                    height: height),
              ),
            ),
            Positioned.fill(
              child: ClipPath(
                clipper: const _SlashClipper(rightSide: true),
                child: _BattleThumb(
                    userId: challengerUserId,
                    gender: challengerGender,
                    alignX: 0.55,
                    height: height),
              ),
            ),
            // 두 이미지가 만나는 대각선을 민트색 스티치 라인으로 또렷하게 구분한다.
            const Positioned.fill(
              child: CustomPaint(painter: _SlashSeamPainter()),
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text('⚔️', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "/" 모양 대각선 슬래시 클리퍼 — rightSide=false면 대각선 왼쪽(호스트),
/// true면 오른쪽(상대) 영역만 남긴다.
class _SlashClipper extends CustomClipper<Path> {
  final bool rightSide;
  const _SlashClipper({required this.rightSide});

  @override
  Path getClip(Size size) {
    final centerX = size.width / 2;
    final halfSkew = size.width * 0.12;
    final topX = centerX + halfSkew;
    final bottomX = centerX - halfSkew;
    final path = Path();
    if (!rightSide) {
      path.moveTo(0, 0);
      path.lineTo(topX, 0);
      path.lineTo(bottomX, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(topX, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(bottomX, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _SlashClipper oldClipper) =>
      oldClipper.rightSide != rightSide;
}

/// 대각선 슬래시 이음매를 따라 그려주는 민트색 스티치 라인 — 두 대결 영역의 경계를
/// 화이트 언더레이 위에 민트색 선으로 또렷하게 구분해준다.
class _SlashSeamPainter extends CustomPainter {
  const _SlashSeamPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final halfSkew = size.width * 0.12;
    final topX = centerX + halfSkew;
    final bottomX = centerX - halfSkew;
    final path = Path()
      ..moveTo(topX, 0)
      ..lineTo(bottomX, size.height);

    final whiteUnderlay = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final mintLine = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, whiteUnderlay);
    canvas.drawPath(path, mintLine);
  }

  @override
  bool shouldRepaint(covariant _SlashSeamPainter oldDelegate) => false;
}

class _BattleThumb extends StatelessWidget {
  final String? userId;
  final String? gender;
  final double alignX;
  final double height;
  const _BattleThumb(
      {this.userId, this.gender, this.alignX = 0, required this.height});

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) return _BattleThumbPlaceholder(height: height);
    // 이미지 내용을 자르지 않고 그대로 축소해서 프레임에 맞춘다 — 남는 여백은
    // 옅은 쿨 오프화이트로 채우고(탁한 파스텔 톤 대신), alignX로 각자의 절반
    // 영역 쪽에 붙여서 대각선이 얼굴 한가운데를 가르지 않게 한다.
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.paper,
      child: Image.asset(
        battleAvatarFor(uid, gender),
        fit: BoxFit.contain,
        alignment: Alignment(alignX, 0),
      ),
    );
  }
}

class _BattleThumbPlaceholder extends StatelessWidget {
  final double height;
  const _BattleThumbPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    // 이 플레이스홀더는 항상 상대(오른쪽) 자리에서만 쓰이는데, 슬래시 클리퍼가
    // 대각선 왼쪽을 잘라내므로 내용을 오른쪽으로 살짝 밀어서 안전 영역에만 그린다.
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ink.withValues(alpha: 0.85), AppColors.ink],
        ),
      ),
      alignment: const Alignment(0.45, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('❓', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(tr('대기 중...🔥', 'Waiting...🔥'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70)),
        ],
      ),
    );
  }
}
