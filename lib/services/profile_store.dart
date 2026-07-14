import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// 회원가입/프로필 상태 (싱글턴). public.users 테이블을 통해 Supabase와 동기화한다.
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  SupabaseClient get _client => Supabase.instance.client;

  UserProfile? currentProfile;

  /// 이메일 인증이 필요해 가입 직후 세션이 없을 때 임시로 들고 있다가,
  /// 인증 후 첫 로그인에서 세션이 생기면 그때 public.users에 저장한다.
  /// (앱을 재시작하면 사라지므로, 그 경우 로그인은 되지만 프로필은 없는 상태가 될 수 있다 — 알려진 한계)
  UserProfile? _pendingProfile;

  void stagePendingProfile(UserProfile profile) {
    _pendingProfile = profile;
  }

  /// 로그인 세션의 uuid로 public.users에서 내 프로필을 불러온다
  Future<void> loadCurrentProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      currentProfile = null;
      notifyListeners();
      return;
    }
    final row = await _client.from('users').select().eq('id', uid).maybeSingle();
    final pending = _pendingProfile;
    if (row == null && pending != null && pending.id == uid) {
      await _client.from('users').insert(pending.toInsertRow());
      currentProfile = pending;
      _pendingProfile = null;
    } else {
      currentProfile = row == null ? null : UserProfile.fromRow(row);
    }
    notifyListeners();
  }

  /// 로그아웃 시 로컬 프로필 캐시를 비운다
  void clear() {
    currentProfile = null;
    notifyListeners();
  }

  Future<bool> isUsernameTaken(String username) async {
    final row = await _client.from('users').select('id').eq('username', username).maybeSingle();
    return row != null;
  }

  Future<bool> isNicknameTaken(String nickname) async {
    final row = await _client.from('users').select('id').eq('nickname', nickname).maybeSingle();
    return row != null;
  }

  /// auth.signUp 이후 호출 — public.users에 프로필 행을 만든다
  Future<void> register(UserProfile profile) async {
    await _client.from('users').insert(profile.toInsertRow());
    currentProfile = profile;
    notifyListeners();
  }

  /// 게시판/랭킹에서 다른 사용자의 프로필을 볼 때 사용 — public.users는 전체 공개 조회라 누구든 조회 가능
  Future<UserProfile?> fetchById(String id) async {
    if (currentProfile?.id == id) return currentProfile;
    final row = await _client.from('users').select().eq('id', id).maybeSingle();
    return row == null ? null : UserProfile.fromRow(row);
  }

  /// 랭킹 화면에서 전체 사용자 목록을 보여줄 때 사용
  Future<List<UserProfile>> fetchAll() async {
    final rows = await _client.from('users').select();
    return (rows as List).map((row) => UserProfile.fromRow(row)).toList();
  }
}
