import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { ko, en }

/// 앱 전체 표시 언어 (싱글턴). 상단 언어 전환 버튼으로 언제든 바꿀 수 있다.
class LocaleStore extends ChangeNotifier {
  LocaleStore._();
  static final LocaleStore instance = LocaleStore._();

  static const _languageKey = 'app_language';

  AppLanguage _language = AppLanguage.ko;
  AppLanguage get language => _language;
  bool get isKorean => _language == AppLanguage.ko;

  /// main.dart에서 앱 시작 시(runApp 이전) 한 번 호출해 기기에 저장된 마지막 언어를 불러온다.
  /// 이걸 먼저 해야 즉시 유통기한 알림처럼 로딩 직후 발동되는 로직도 올바른 언어로 뜬다.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_languageKey);
    if (saved == AppLanguage.en.name) {
      _language = AppLanguage.en;
    }
  }

  void toggle() {
    _language = isKorean ? AppLanguage.en : AppLanguage.ko;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_languageKey, _language.name));
  }
}
