import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'locale_store.dart';

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

  // 영문판(LocaleStore.isKorean == false)에서도 같은 문장 패턴으로 명령을 인식할 수 있도록
  // 한글/영어 표현을 하나의 정규식에 함께 넣는다.
  static final _nextStepPattern =
      RegExp(r'다음\s?단계|다음|넘어가|\bnext\s?step\b|\bnext\b', caseSensitive: false);
  static final _previousStepPattern = RegExp(
      r'이전\s?단계|이전|뒤로|\bprevious\s?step\b|\bprevious\b|\bback\b|go\s?back',
      caseSensitive: false);
  static final _timerPattern = RegExp(r'(\d+)\s*분\s*타이머');
  static final _timerPatternEn = RegExp(
      r'(\d+)\s*(?:min|mins|minute|minutes)\s*timer|timer\s*(?:for)?\s*(\d+)\s*(?:min|mins|minute|minutes)',
      caseSensitive: false);

  final SpeechToText _speech = SpeechToText();
  AudioPlayer? _alarmPlayer;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _continuousMode = false;
  void Function(VoiceCommand command)? _activeOnCommand;
  String? _unavailableReason;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool get isListening => _isListening;

  /// true면 한 문장을 인식한 뒤에도 마이크를 끄지 않고 자동으로 다시 듣기 시작한다.
  /// 마이크 버튼을 길게 눌러 켤 수 있으며, 매 스텝마다 다시 탭할 필요가 없어진다.
  bool get isContinuousMode => _continuousMode;

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
          // error_no_match(못 알아들음)/error_speech_timeout(무음) 등은 연속 듣기 중
          // 아주 흔하게 발생하는 일시적인 상황이다 — 이걸로 마이크를 영구 "사용 불가"
          // 상태로 만들면 이후 탭할 때마다 에러 배너가 뜨고 마이크가 계속 꺼진 채로
          // 남는다. 실제 권한 문제일 때만 unavailableReason을 채운다.
          _isListening = false;
          if (error.errorMsg == 'error_insufficient_permissions') {
            _unavailableReason =
                '마이크 권한이 거부되어 음성 셰프를 사용할 수 없어요. 설정에서 권한을 허용해주세요.';
          } else {
            debugPrint(
                'VoiceChefService: 일시적 인식 오류(무시) - ${error.errorMsg}');
          }
          notifyListeners();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
            if (_continuousMode && _activeOnCommand != null) {
              _restartListening();
            }
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

  /// 한 문장을 듣고 인식되는 즉시 [onCommand]로 명령을 전달한다.
  /// [continuous]가 true면 한 문장이 끝나도 마이크를 끄지 않고 자동으로 다시 듣기를
  /// 시작한다(연속 듣기 모드) — 사용자가 매 스텝마다 마이크를 다시 누를 필요가 없다.
  /// init()에서 실패했다면(unavailableReason != null) 호출하지 않는다.
  Future<void> startListening(
    void Function(VoiceCommand command) onCommand, {
    bool continuous = false,
  }) async {
    if (!_isInitialized || _isListening) return;
    _continuousMode = continuous;
    _activeOnCommand = onCommand;
    await _listenOnce(onCommand);
  }

  Future<void> _listenOnce(void Function(VoiceCommand command) onCommand) async {
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
        // 앱이 영문 모드면 영어 음성 인식 모델(en_US)로, 아니면 한국어(ko_KR)로 듣는다.
        // 지정하지 않으면 기기 시스템 언어를 쓰는데, 시스템이 한국어인 기기에서 영문
        // 모드로 "next"라고 말해도 한국어 인식기가 잘못 알아듣는 문제가 있었다.
        localeId: LocaleStore.instance.isKorean ? 'ko_KR' : 'en_US',
      ),
    );
  }

  /// 연속 듣기 모드에서 한 문장 인식이 끝난 직후 자동으로 다시 듣기를 시작한다.
  /// speech_to_text가 세션을 완전히 정리할 시간을 주기 위해 짧은 지연을 둔다.
  Future<void> _restartListening() async {
    final onCommand = _activeOnCommand;
    if (onCommand == null) return;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_continuousMode || _isListening || onCommand != _activeOnCommand) return;
    await _listenOnce(onCommand);
  }

  /// 마이크를 끄고 연속 듣기 모드도 함께 해제한다.
  Future<void> stopListening() async {
    _continuousMode = false;
    _activeOnCommand = null;
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
    final timerMatchEn = _timerPatternEn.firstMatch(recognizedWords);
    if (timerMatchEn != null) {
      final minutesText = timerMatchEn.group(1) ?? timerMatchEn.group(2)!;
      return VoiceCommand.setTimer(Duration(minutes: int.parse(minutesText)));
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
