import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/locale_store.dart';
import 'screens/fridge_screen.dart';

// Supabase 연동 시 아래 주석 해제 후 URL/anon key 입력
// import 'package:supabase_flutter/supabase_flutter.dart';
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Supabase.initialize(
//     url: 'YOUR_SUPABASE_URL',
//     anonKey: 'YOUR_SUPABASE_ANON_KEY',
//   );
//   runApp(const FridgeChefApp());
// }

void main() {
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
        home: const FridgeScreen(),
      ),
    );
  }
}
