import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/chef_points_store.dart';
import '../services/fridge_store.dart';
import '../services/profile_store.dart';
import '../services/push_notification_service.dart';
import '../services/realtime_notification_manager.dart';
import '../theme/app_theme.dart';
import 'main_dashboard_screen.dart';
import 'sign_in_screen.dart';

/// Supabase 세션 유무에 따라 로그인 화면 또는 냉장고 화면을 보여준다.
/// 로그인/로그아웃이 일어나면 onAuthStateChange 스트림을 통해 자동으로 다시 그려진다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _profileLoadedForUid;
  Future<void>? _profileFuture;

  /// 프로필 + 요리 포인트를 함께 불러온다 — 냉장고 화면 이후 어디서든 recordCook/recordInvite가
  /// 호출될 수 있으므로 ChefPointsStore도 로그인 직후에 미리 로드해둔다
  Future<void> _ensureProfileLoaded(String uid) {
    if (_profileLoadedForUid != uid) {
      _profileLoadedForUid = uid;
      _profileFuture = Future.wait([
        ProfileStore.instance.loadCurrentProfile(),
        ChefPointsStore.instance.loadEvents(),
      ]);
    }
    return _profileFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.instance.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? AuthService.instance.currentSession;
        if (session == null) {
          _profileLoadedForUid = null;
          ProfileStore.instance.clear();
          FridgeStore.instance.clear();
          ChefPointsStore.instance.clear();
          RealtimeNotificationManager.instance.stopListening();
          PushNotificationService.instance.unregister();
          return const SignInScreen();
        }
        RealtimeNotificationManager.instance.startListening();
        PushNotificationService.instance.registerForUser(session.user.id);
        return FutureBuilder<void>(
          future: _ensureProfileLoaded(session.user.id),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                backgroundColor: AppColors.paper,
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return const MainDashboardScreen();
          },
        );
      },
    );
  }
}
