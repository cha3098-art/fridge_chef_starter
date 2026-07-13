/// users 테이블 확장 — 회원가입 시 입력하는 개인정보 프로필
class UserProfile {
  final String id;
  final String nickname;
  final String gender;
  final String nationality;
  final String city;
  final String email;
  final String bio;
  final String? photoPath;

  // 비공개 설정 — true면 다른 사람에게 숨긴다
  final bool hideGender;
  final bool hidePhoto;
  final bool hideNationality;
  final bool hideCity;
  final bool hideEmail;

  const UserProfile({
    required this.id,
    required this.nickname,
    required this.gender,
    required this.nationality,
    required this.city,
    required this.email,
    required this.bio,
    this.photoPath,
    this.hideGender = false,
    this.hidePhoto = false,
    this.hideNationality = false,
    this.hideCity = false,
    this.hideEmail = false,
  });

  /// 다른 사람 눈에 보이는 필드만 남긴 뷰 — 비공개 필드는 null로 가려진다
  UserProfile toPublicView() => UserProfile(
        id: id,
        nickname: nickname,
        gender: hideGender ? '비공개' : gender,
        nationality: hideNationality ? '비공개' : nationality,
        city: hideCity ? '비공개' : city,
        email: hideEmail ? '비공개' : email,
        bio: bio,
        photoPath: hidePhoto ? null : photoPath,
        hideGender: hideGender,
        hideNationality: hideNationality,
        hideCity: hideCity,
        hideEmail: hideEmail,
        hidePhoto: hidePhoto,
      );
}
