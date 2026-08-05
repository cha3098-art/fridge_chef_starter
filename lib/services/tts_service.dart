import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// "설명 읽기" — 조리 단계 텍스트를 한국어 음성으로 읽어주는 서비스.
/// VoiceChefService(마이크/STT)와 동시에 켜둘 수 있으며, 음성 명령이 인식되면
/// CookingModeScreen이 stop()을 먼저 호출해 TTS를 끊고 명령을 우선 처리한다.
class TtsService extends ChangeNotifier {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        _isSpeaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        notifyListeners();
        debugPrint('TtsService error: $msg');
      });
      _isInitialized = true;
    } catch (e) {
      debugPrint('TtsService.init failed: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    if (!_isSpeaking) return;
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
