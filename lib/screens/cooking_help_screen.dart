import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// 요리 시작(음성 모드) 화면의 사용법 안내. 읽기 버튼/마이크 버튼의 동작과
/// 마이크 길게 누르기(연속 듣기), 사용 가능한 음성 명령을 설명한다.
/// CookingModeScreen에서 push되며, 뒤로가기(닫기)를 누르면 원래 조리 화면으로
/// 스텝 진행 상태가 그대로 남은 채 돌아간다.
class CookingHelpScreen extends StatelessWidget {
  const CookingHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14171C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.greenDeep.withValues(alpha: 0.35),
                    const Color(0xFF14171C),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          tr('음성 모드 사용법', 'Voice mode guide'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _GuideCard(
                        icon: Icons.volume_up_rounded,
                        iconColor: AppColors.carrot,
                        title: tr('🔊 읽기 버튼', '🔊 Read-aloud button'),
                        bullets: [
                          tr('한 번 탭하면 지금 보고 있는 단계를 소리 내어 읽어줘요.',
                              'Tap once and it reads the current step out loud.'),
                          tr('켜져 있는 동안엔 다음/이전 단계로 넘어갈 때마다 새 단계를 자동으로 이어 읽어요.',
                              'While it\'s on, it automatically keeps reading each new step as you move forward or back.'),
                          tr('다시 탭하면 읽기를 끌 수 있어요.',
                              'Tap again to turn reading off.'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _GuideCard(
                        icon: Icons.mic_rounded,
                        iconColor: AppColors.green,
                        title: tr('🎙 마이크 버튼', '🎙 Mic button'),
                        bullets: [
                          tr('짧게 탭하면 한 번만 듣고, 명령을 인식하면 자동으로 꺼져요.',
                              'A short tap listens once, then turns off automatically after it recognizes a command.'),
                          tr(
                              '꾹 길게 누르면 "연속 듣기" 모드로 바뀌어요. 매 단계마다 다시 누르지 않아도 계속 음성 명령을 들어요.',
                              'Press and hold to switch to "continuous listening" mode — it keeps listening for commands without needing to be tapped again at every step.'),
                          tr('연속 듣기 중에는 마이크 버튼 테두리가 주황색으로 표시돼요. 탭하면 언제든 끌 수 있어요.',
                              'While continuous mode is active, the mic button shows an orange ring. Tap it anytime to turn it off.'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _GuideCard(
                        icon: Icons.record_voice_over_rounded,
                        iconColor: Colors.white,
                        title: tr('말할 수 있는 명령어', 'Voice commands you can say'),
                        bullets: [
                          tr('"다음 단계" / "다음" / "넘어가" → 다음 스텝으로 이동',
                              '"Next step" / "next" → move to the next step'),
                          tr('"이전 단계" / "이전" / "뒤로" → 이전 스텝으로 이동',
                              '"Previous step" / "previous" / "back" → go back one step'),
                          tr('"5분 타이머" 처럼 "[N]분 타이머" → N분 타이머 시작',
                              '"5 minute timer" style phrase → starts an N-minute timer'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> bullets;

  const _GuideCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: _Dot(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: AppColors.green,
        shape: BoxShape.circle,
      ),
    );
  }
}
