import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/tr.dart';
import 'screens/auth_gate.dart';
import 'screens/onboarding_screen.dart';
import 'services/deeplink_manager.dart';
import 'services/locale_store.dart';
import 'services/notification_service.dart';
import 'supabase_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  var showOnboarding = false;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
    // 초대장 상세 조회가 Supabase에 의존하므로 설정된 경우에만 딥링크 리스너를 켠다
    await DeeplinkManager.instance.init();
    showOnboarding = !await OnboardingScreen.hasSeen();
  }
  runApp(FridgeChefApp(showOnboarding: showOnboarding));
}

class FridgeChefApp extends StatelessWidget {
  final bool showOnboarding;

  const FridgeChefApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: DeeplinkManager.instance.navigatorKey,
        title: '냉장고 셰프',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: !SupabaseConfig.isConfigured
            ? const _SupabaseSetupNeededScreen()
            : showOnboarding
                ? const OnboardingScreen()
                : const AuthGate(),
      ),
    );
  }
}

/// lib/supabase_config.dart에 실제 URL/anon key가 채워지기 전까지 보여주는 안내 화면
class _SupabaseSetupNeededScreen extends StatelessWidget {
  const _SupabaseSetupNeededScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.inkSoft),
              const SizedBox(height: 16),
              Text(
                tr('Supabase 설정이 필요해요', 'Supabase setup needed'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'lib/supabase_config.dart 파일에\nsupabase.com 프로젝트의 URL과 anon key를 입력해주세요.',
                  'Fill in your Supabase project URL and anon key\nin lib/supabase_config.dart.',
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
