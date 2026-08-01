/// 배틀 카드/상세 화면에서 실제 얼굴 사진 대신 쓰는 성별 맞춤 마스코트 아바타.
/// 실제 무작위(Random)를 쓰면 위젯이 다시 그려질 때마다 아바타가 바뀌어 보이므로,
/// userId를 시드로 삼아 같은 유저는 항상 같은 아바타가 나오는 "고정된 랜덤"을 쓴다.
const List<String> maleBattleAvatars = [
  'assets/battle_avatars/male_1.jpg',
  'assets/battle_avatars/male_2.jpg',
  'assets/battle_avatars/male_3.jpg',
];

const List<String> femaleBattleAvatars = [
  'assets/battle_avatars/female_1.jpg',
  'assets/battle_avatars/female_2.jpg',
  'assets/battle_avatars/female_3.jpg',
];

const List<String> allBattleAvatars = [
  ...maleBattleAvatars,
  ...femaleBattleAvatars,
];

/// [gender]가 '남성'/'여성'이면 해당 성별 풀에서, 그 외(선택 안 함/비공개/알 수 없음)에는
/// 전체 6종 중에서 userId 기반으로 하나를 고정 선택한다.
String battleAvatarFor(String userId, String? gender) {
  final pool = switch (gender) {
    '남성' => maleBattleAvatars,
    '여성' => femaleBattleAvatars,
    _ => allBattleAvatars,
  };
  final index = userId.hashCode.abs() % pool.length;
  return pool[index];
}
