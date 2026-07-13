import 'package:flutter/foundation.dart';

enum AppLanguage { ko, en }

/// 앱 전체 표시 언어 (싱글턴). 상단 언어 전환 버튼으로 언제든 바꿀 수 있다.
class LocaleStore extends ChangeNotifier {
  LocaleStore._();
  static final LocaleStore instance = LocaleStore._();

  AppLanguage _language = AppLanguage.ko;
  AppLanguage get language => _language;
  bool get isKorean => _language == AppLanguage.ko;

  void toggle() {
    _language = isKorean ? AppLanguage.en : AppLanguage.ko;
    notifyListeners();
  }
}
