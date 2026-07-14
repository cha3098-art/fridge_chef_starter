import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth를 감싸는 얇은 래퍼
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({required String email, required String password}) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();
}
