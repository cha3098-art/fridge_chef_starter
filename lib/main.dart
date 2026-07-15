import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/tr.dart';
import 'screens/auth_gate.dart';
import 'services/locale_store.dart';
import 'services/notification_service.dart';
import 'supabase_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  }
  runApp(const FridgeChefApp());
}

class FridgeChefApp extends StatelessWidget {
  const FridgeChefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) => MaterialApp(
        title: '냉장고 셰프',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: SupabaseConfig.isConfigured ? const AuthGate() : const _SupabaseSetupNeededScreen(),
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
