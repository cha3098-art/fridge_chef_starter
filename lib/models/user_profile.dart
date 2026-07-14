/// users 테이블 확장 — 회원가입 시 입력하는 개인정보 프로필
/// [id]는 Supabase auth.users의 uuid, [username]은 사람이 고른 로그인 아이디다.
class UserProfile {
  final String id;
  final String username;
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
    required this.username,
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

  /// Supabase public.users 행을 UserProfile로 변환한다
  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
        id: row['id'] as String,
        username: row['username'] as String,
        nickname: row['nickname'] as String,
        gender: row['gender'] as String? ?? '',
        nationality: row['nationality'] as String? ?? '',
        city: row['city'] as String? ?? '',
        email: row['email'] as String? ?? '',
        bio: row['bio'] as String? ?? '',
        photoPath: row['photo_url'] as String?,
        hideGender: row['hide_gender'] as bool? ?? false,
        hidePhoto: row['hide_photo'] as bool? ?? false,
        hideNationality: row['hide_nationality'] as bool? ?? false,
        hideCity: row['hide_city'] as bool? ?? false,
        hideEmail: row['hide_email'] as bool? ?? false,
      );

  /// public.users insert에 쓸 행 — id는 auth uid를 그대로 쓰므로 별도 전달한다
  Map<String, dynamic> toInsertRow() => {
        'id': id,
        'username': username,
        'nickname': nickname,
        'email': email,
        'gender': gender,
        'nationality': nationality,
        'city': city,
        'bio': bio,
        'photo_url': photoPath,
        'hide_gender': hideGender,
        'hide_photo': hidePhoto,
        'hide_nationality': hideNationality,
        'hide_city': hideCity,
        'hide_email': hideEmail,
      };

  /// 다른 사람 눈에 보이는 필드만 남긴 뷰 — 비공개 필드는 null로 가려진다
  UserProfile toPublicView() => UserProfile(
        id: id,
        username: username,
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
