import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceCommandType { nextStep, previousStep, setTimer }

class VoiceCommand {
  final VoiceCommandType type;
  final Duration? timerDuration;

  const VoiceCommand.nextStep()
      : type = VoiceCommandType.nextStep,
        timerDuration = null;
  const VoiceCommand.previousStep()
      : type = VoiceCommandType.previousStep,
        timerDuration = null;
  const VoiceCommand.setTimer(Duration duration)
      : type = VoiceCommandType.setTimer,
        timerDuration = duration;
}

/// "음성 셰프 타이머" — 조리 중 손이 자유롭지 않을 때 음성으로 스텝 이동/타이머 설정을 하는 서비스.
/// speech_to_text로 인식한 문장을 정규식으로 매칭해 VoiceCommand로 변환하고,
/// N분 타이머 명령은 자체 카운트다운까지 관리한 뒤 종료 시 audioplayers로 알람음을 재생한다.
class VoiceChefService extends ChangeNotifier {
  VoiceChefService._();
  static final VoiceChefService instance = VoiceChefService._();

  static final _nextStepPattern = RegExp(r'다음\s?단계|다음|넘어가');
  static final _previousStepPattern = RegExp(r'이전\s?단계|이전|뒤로');
  static final _timerPattern = RegExp(r'(\d+)\s*분\s*타이머');

  final SpeechToText _speech = SpeechToText();
  AudioPlayer? _alarmPlayer;

  bool _isInitialized = false;
  bool _isListening = false;
  String? _unavailableReason;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool get isListening => _isListening;

  /// 마이크/음성인식이 지원되지 않거나 권한이 거부된 경우 안내 문구. null이면 사용 가능.
  String? get unavailableReason => _unavailableReason;

  Duration get remaining => _remaining;
  Duration get totalDuration => _totalDuration;
  bool get isTimerRunning => _countdownTimer != null;

  /// speech_to_text 플러그인을 초기화한다 (마이크/음성인식 권한 요청 포함).
  /// 기기가 음성 인식을 지원하지 않거나 사용자가 권한을 거부하면 false를 반환하고
  /// unavailableReason에 안내 문구를 채운다.
  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      final available = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          _unavailableReason = '음성 인식 중 오류가 발생했어요 (${error.errorMsg}).';
          notifyListeners();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
      );
      _isInitialized = available;
      _unavailableReason = available
          ? null
          : '이 기기에서는 음성 인식을 사용할 수 없어요. 마이크 권한을 허용했는지 설정에서 확인해주세요.';
      return available;
    } catch (e) {
      _isInitialized = false;
      _unavailableReason = '마이크 권한이 거부되어 음성 셰프를 사용할 수 없어요. 설정에서 권한을 허용해주세요.';
      debugPrint('VoiceChefService.init failed: $e');
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// 계속 듣기 모드로 진입해 인식되는 문장마다 [onCommand]로 명령을 전달한다.
  /// init()에서 실패했다면(unavailableReason != null) 호출하지 않는다.
  Future<void> startListening(
      void Function(VoiceCommand command) onCommand) async {
    if (!_isInitialized || _isListening) return;
    _isListening = true;
    notifyListeners();
    await _speech.listen(
      onResult: (result) {
        final command = parseCommand(result.recognizedWords);
        if (command != null) onCommand(command);
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: false,
      ),
    );
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  /// 인식된 문장에서 명령을 추출한다. 매칭되는 명령이 없으면 null.
  /// "[N]분 타이머" 형태가 다음/이전 표현보다 더 구체적이므로 먼저 검사한다.
  @visibleForTesting
  VoiceCommand? parseCommand(String recognizedWords) {
    final timerMatch = _timerPattern.firstMatch(recognizedWords);
    if (timerMatch != null) {
      final minutes = int.parse(timerMatch.group(1)!);
      return VoiceCommand.setTimer(Duration(minutes: minutes));
    }
    if (_nextStepPattern.hasMatch(recognizedWords)) {
      return const VoiceCommand.nextStep();
    }
    if (_previousStepPattern.hasMatch(recognizedWords)) {
      return const VoiceCommand.previousStep();
    }
    return null;
  }

  /// N분 타이머를 시작한다. 이미 실행 중이면 새 타이머로 교체한다.
  /// onTick은 매초, onDone은 종료(알람 재생) 시 호출된다.
  void startTimer(
    Duration duration, {
    void Function(Duration remaining)? onTick,
    VoidCallback? onDone,
  }) {
    _countdownTimer?.cancel();
    _remaining = duration;
    _totalDuration = duration;
    notifyListeners();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _remaining = Duration.zero;
        timer.cancel();
        _countdownTimer = null;
        notifyListeners();
        _playAlarm();
        onDone?.call();
      } else {
        _remaining = next;
        notifyListeners();
        onTick?.call(_remaining);
      }
    });
  }

  void cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _remaining = Duration.zero;
    _totalDuration = Duration.zero;
    notifyListeners();
  }

  Future<void> _playAlarm() async {
    try {
      final player = _alarmPlayer ??= AudioPlayer();
      await player.play(AssetSource('sounds/timer_alarm.wav'));
    } catch (e) {
      debugPrint('VoiceChefService._playAlarm failed: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _alarmPlayer?.dispose();
    super.dispose();
  }
}
