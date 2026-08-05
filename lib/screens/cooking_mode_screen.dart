import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/tts_service.dart';
import '../services/voice_chef_service.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/step_visual.dart';

/// 핸즈프리 "요리 시작 모드" — 조리 중 화면을 만지지 않아도 음성으로 스텝 이동/타이머를
/// 설정할 수 있는 풀스크린 모드. Recipe(정식 레시피)와 QuickRecipe(초간단 레시피) 양쪽에서
/// 재사용할 수 있도록 사진/제목/스텝 텍스트만 받는다.
class CookingModeScreen extends StatefulWidget {
  final String title;
  final String? photoUrl;
  final String cuisineType;
  final String emoji;
  final List<String> steps;

  /// steps와 같은 길이의 단계별 비주얼 이미지 경로(assets/images/steps/...). 항목이 null이면
  /// 그 단계는 카테고리 라인 아이콘으로 대체된다. 통째로 비워두면(steps보다 짧으면) 전부 대체된다.
  final List<String?> stepImages;

  const CookingModeScreen({
    super.key,
    required this.title,
    required this.cuisineType,
    required this.emoji,
    required this.steps,
    this.stepImages = const [],
    this.photoUrl,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  final VoiceChefService _voice = VoiceChefService.instance;
  final TtsService _tts = TtsService.instance;
  int _stepIndex = 0;

  /// true면 [다음 단계]/[이전 단계]로 이동할 때마다 새 스텝 설명을 자동으로 이어 읽는다.
  bool _autoReadEnabled = false;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceChanged);
    _voice.init();
    _tts.addListener(_onVoiceChanged);
    _tts.init();
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    _voice.stopListening();
    _voice.cancelTimer();
    _tts.removeListener(_onVoiceChanged);
    _tts.stop();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  void _nextStep() {
    if (_stepIndex < widget.steps.length - 1) {
      setState(() => _stepIndex++);
      _readCurrentStepIfEnabled();
    }
  }

  void _previousStep() {
    if (_stepIndex > 0) {
      setState(() => _stepIndex--);
      _readCurrentStepIfEnabled();
    }
  }

  void _readCurrentStepIfEnabled() {
    if (_autoReadEnabled) _tts.speak(widget.steps[_stepIndex]);
  }

  Future<void> _toggleReadAloud() async {
    if (_autoReadEnabled) {
      setState(() => _autoReadEnabled = false);
      await _tts.stop();
    } else {
      setState(() => _autoReadEnabled = true);
      await _tts.speak(widget.steps[_stepIndex]);
    }
  }

  void _handleVoiceCommand(VoiceCommand command) {
    // TTS가 읽는 중이어도 음성 명령이 인식되면 그 즉시 읽기를 멈추고 명령을 우선 처리한다.
    if (_tts.isSpeaking) _tts.stop();
    switch (command.type) {
      case VoiceCommandType.nextStep:
        _nextStep();
      case VoiceCommandType.previousStep:
        _previousStep();
      case VoiceCommandType.setTimer:
        _startTimer(command.timerDuration!);
    }
  }

  void _startTimer(Duration duration) {
    _voice.startTimer(
      duration,
      onDone: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('⏰ 타이머가 끝났어요!', '⏰ Timer\'s up!')),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _toggleMic() async {
    if (_voice.unavailableReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_voice.unavailableReason!),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_voice.isListening) {
      await _voice.stopListening();
    } else {
      await _voice.startListening(_handleVoiceCommand);
    }
  }

  Future<void> _openTimerPicker() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFFECFDF5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('⏱ 타이머 설정', '⏱ Set timer'),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [1, 3, 5, 10, 15, 20]
                  .map((m) => GestureDetector(
                        onTap: () => Navigator.pop(sheetContext, m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(tr('$m분', '$m min'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
    if (minutes != null) _startTimer(Duration(minutes: minutes));
  }

  Widget _background() {
    final gradient = cuisineGradient(widget.cuisineType);
    final photoUrl = widget.photoUrl;
    if (photoUrl == null || photoUrl.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(widget.emoji, style: const TextStyle(fontSize: 96)),
        ),
      );
    }
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Center(
          child: Text(widget.emoji, style: const TextStyle(fontSize: 96)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = widget.steps.length;
    final step = widget.steps[_stepIndex];
    final stepImage = _stepIndex < widget.stepImages.length
        ? widget.stepImages[_stepIndex]
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _background()),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: widget.title,
                  stepIndex: _stepIndex,
                  totalSteps: totalSteps,
                  onClose: () => Navigator.of(context).pop(),
                ),
                if (_voice.isTimerRunning) ...[
                  const SizedBox(height: 12),
                  _TimerRing(
                    remaining: _voice.remaining,
                    total: _voice.totalDuration,
                  ),
                ],
                Expanded(
                  child: Center(
                    child: _GlassStepPanel(
                      stepIndex: _stepIndex,
                      totalSteps: totalSteps,
                      description: step,
                      imageAsset: stepImage,
                      recipePhotoUrl: widget.photoUrl,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ReadAloudButton(
                      active: _autoReadEnabled,
                      speaking: _tts.isSpeaking,
                      onTap: _toggleReadAloud,
                    ),
                    const SizedBox(width: 28),
                    _MicWaveform(
                      isListening: _voice.isListening,
                      unavailable: _voice.unavailableReason != null,
                      onTap: _toggleMic,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _BottomControls(
                  onPrevious: _stepIndex > 0 ? _previousStep : null,
                  onNext: _stepIndex < totalSteps - 1 ? _nextStep : null,
                  onTimer: _openTimerPicker,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onClose;

  const _TopBar({
    required this.title,
    required this.stepIndex,
    required this.totalSteps,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'STEP ${stepIndex + 1}/$totalSteps',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// 중앙 반투명 화이트 글래스 패널 — 조리 단계 텍스트를 멀리서도 읽히도록 크게 보여준다.
class _GlassStepPanel extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final String description;
  final String? imageAsset;
  final String? recipePhotoUrl;

  const _GlassStepPanel({
    required this.stepIndex,
    required this.totalSteps,
    required this.description,
    this.imageAsset,
    this.recipePhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepVisual(
                  imageAsset: imageAsset,
                  recipePhotoUrl: recipePhotoUrl,
                  stepDescription: description,
                  height: 190,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(height: 18),
                Text(
                  'STEP ${stepIndex + 1} / $totalSteps',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 네온 민트/피치 원형 타이머 프로그레스
class _TimerRing extends StatelessWidget {
  final Duration remaining;
  final Duration total;

  const _TimerRing({required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds == 0
        ? 0.0
        : remaining.inMilliseconds / total.inMilliseconds;
    final minutes =
        remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppColors.green, AppColors.carrot],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
            child: SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 9,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
          ),
        ],
      ),
    );
  }
}

/// [🔊 설명 읽기] 토글 버튼 — 켜져 있으면 현재 스텝을 읽고, 스텝 이동 시 자동으로 이어 읽는다.
/// 읽는 중일 때 민트/오렌지 그라데이션 글로우 펄스 애니메이션 + '읽는 중...' 라벨을 보여준다.
class _ReadAloudButton extends StatefulWidget {
  final bool active;
  final bool speaking;
  final VoidCallback onTap;

  const _ReadAloudButton({
    required this.active,
    required this.speaking,
    required this.onTap,
  });

  @override
  State<_ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends State<_ReadAloudButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 18,
          child: widget.speaking
              ? Text(
                  tr('읽는 중...', 'Reading...'),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse = widget.speaking ? _controller.value : 0.0;
            return GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.active
                      ? AppColors.carrot
                      : Colors.white.withValues(alpha: 0.16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  boxShadow: widget.speaking
                      ? [
                          BoxShadow(
                            color: Color.lerp(AppColors.green, AppColors.carrot,
                                    pulse)!
                                .withValues(alpha: 0.55),
                            blurRadius: 14 + pulse * 10,
                            spreadRadius: 1 + pulse * 3,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  widget.active ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 음성 수신 중임을 알리는 마이크 인디케이터 + 파동(Waveform) 애니메이션
class _MicWaveform extends StatefulWidget {
  final bool isListening;
  final bool unavailable;
  final VoidCallback onTap;

  const _MicWaveform({
    required this.isListening,
    required this.unavailable,
    required this.onTap,
  });

  @override
  State<_MicWaveform> createState() => _MicWaveformState();
}

class _MicWaveformState extends State<_MicWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final active = widget.isListening;
              final phase = _controller.value * 2 * math.pi + i * 0.8;
              final height = active ? 8 + (1 + math.sin(phase)) * 10 : 6.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 5,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [AppColors.green, AppColors.carrot],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isListening
                  ? AppColors.green
                  : Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              boxShadow: widget.isListening
                  ? [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.unavailable ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onTimer;

  const _BottomControls({
    required this.onPrevious,
    required this.onNext,
    required this.onTimer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ControlButton(
              icon: Icons.chevron_left_rounded,
              label: tr('이전 단계', 'Previous'),
              onTap: onPrevious,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: Icons.timer_outlined,
              label: tr('타이머', 'Timer'),
              onTap: onTimer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ControlButton(
              icon: Icons.chevron_right_rounded,
              label: tr('다음 단계', 'Next'),
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.4),
                size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: enabled ? 1 : 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
