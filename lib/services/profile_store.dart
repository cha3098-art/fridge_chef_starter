import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

/// 회원가입/프로필 상태 (싱글턴, 메모리에만 보관)
/// 실제 서버가 없으므로 아이디/닉네임 중복확인은 이 안에 미리 심어둔 목업 사용자 +
/// 현재 세션에서 가입한 프로필을 기준으로 동작한다.
/// TODO: Supabase 연동 시 auth.users + public.users 기반 실제 중복확인으로 교체
class ProfileStore extends ChangeNotifier {
  ProfileStore._();
  static final ProfileStore instance = ProfileStore._();

  UserProfile? currentProfile;

  /// 랭킹/게시판을 채우기 위한 목업 사용자 — 실제 서버 데이터가 아님을 명확히 한다
  static const mockProfiles = <UserProfile>[
    UserProfile(
      id: 'chef_kim',
      nickname: '집밥킴',
      gender: '여성',
      nationality: '대한민국',
      city: '서울',
      email: 'chef_kim@example.com',
      bio: '매일 냉장고를 털어 요리해요!',
    ),
    UserProfile(
      id: 'foodlover88',
      nickname: '맛잘알',
      gender: '남성',
      nationality: '대한민국',
      city: '부산',
      email: 'foodlover88@example.com',
      bio: 'K-Food 챌린지 중입니다.',
      hideEmail: true,
      hideCity: true,
    ),
    UserProfile(
      id: 'jenny_cook',
      nickname: '제니쿡',
      gender: '여성',
      nationality: '미국',
      city: 'LA',
      email: 'jenny@example.com',
      bio: 'Korean food fan from LA!',
      hideNationality: true,
      hideGender: true,
    ),
    UserProfile(
      id: 'minsu_chef',
      nickname: '민수요리',
      gender: '남성',
      nationality: '대한민국',
      city: '대전',
      email: 'minsu@example.com',
      bio: '떡볶이가 제일 좋아요.',
    ),
  ];

  Set<String> get _takenIds => {
        ...mockProfiles.map((p) => p.id),
        if (currentProfile != null) currentProfile!.id,
      };

  Set<String> get _takenNicknames => {
        ...mockProfiles.map((p) => p.nickname),
        if (currentProfile != null) currentProfile!.nickname,
      };

  bool isIdTaken(String id) => _takenIds.contains(id);

  bool isNicknameTaken(String nickname) => _takenNicknames.contains(nickname);

  void register(UserProfile profile) {
    currentProfile = profile;
    notifyListeners();
  }

  UserProfile? findById(String id) {
    if (currentProfile?.id == id) return currentProfile;
    for (final p in mockProfiles) {
      if (p.id == id) return p;
    }
    return null;
  }
}
