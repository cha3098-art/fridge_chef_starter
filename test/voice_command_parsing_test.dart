import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_chef/services/voice_chef_service.dart';

void main() {
  final service = VoiceChefService.instance;

  test('"다음" 계열 명령을 인식한다', () {
    for (final phrase in ['다음', '다음 단계', '다음단계로 넘어가', '넘어가']) {
      final command = service.parseCommand(phrase);
      expect(command?.type, VoiceCommandType.nextStep, reason: phrase);
    }
  });

  test('"이전" 계열 명령을 인식한다', () {
    for (final phrase in ['이전', '이전 단계', '뒤로']) {
      final command = service.parseCommand(phrase);
      expect(command?.type, VoiceCommandType.previousStep, reason: phrase);
    }
  });

  test('영어 "next"/"previous" 계열 명령을 인식한다', () {
    for (final phrase in ['next', 'Next step', 'go next step']) {
      final command = service.parseCommand(phrase);
      expect(command?.type, VoiceCommandType.nextStep, reason: phrase);
    }
    for (final phrase in ['previous', 'Previous step', 'go back']) {
      final command = service.parseCommand(phrase);
      expect(command?.type, VoiceCommandType.previousStep, reason: phrase);
    }
  });

  test('영어 "[N] minute timer" 명령에서 분을 추출한다', () {
    final command = service.parseCommand('set a 5 minute timer');
    expect(command?.type, VoiceCommandType.setTimer);
    expect(command?.timerDuration, const Duration(minutes: 5));

    final command2 = service.parseCommand('timer for 3 min');
    expect(command2?.timerDuration, const Duration(minutes: 3));
  });

  test('"[N]분 타이머" 명령에서 분을 추출한다', () {
    final command = service.parseCommand('3분 타이머 맞춰줘');
    expect(command?.type, VoiceCommandType.setTimer);
    expect(command?.timerDuration, const Duration(minutes: 3));

    final command2 = service.parseCommand('5분 타이머');
    expect(command2?.timerDuration, const Duration(minutes: 5));
  });

  test('매칭되는 명령이 없으면 null', () {
    expect(service.parseCommand('오늘 날씨 어때'), isNull);
  });
}
