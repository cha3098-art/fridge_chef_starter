import '../services/locale_store.dart';

/// 한글/영어 문자열을 현재 언어 설정에 맞게 반환한다.
/// 사용: Text(tr('내 냉장고', 'My Fridge'))
String tr(String ko, String en) => LocaleStore.instance.isKorean ? ko : en;

const _tagDictionary = {
  '전체': 'All',
  '15분 이내': 'Under 15 min',
  '30분 이내': 'Under 30 min',
  '60분 이내': 'Under 60 min',
  '하': 'Easy',
  '중': 'Medium',
  '상': 'Hard',
  '한식': 'Korean',
  '중식': 'Chinese',
  '양식': 'Western',
  '분식': 'Snacks',
  '일식': 'Japanese',
  '이탈리아식': 'Italian',
  '프랑스식': 'French',
  '채소': 'Veggies',
  '야채': 'Veggies',
  '육류': 'Meat',
  '유제품': 'Dairy',
  '수산': 'Seafood',
  '생선': 'Seafood',
  '밑반찬': 'Side dishes',
  '소스': 'Sauces',
  '기타': 'Other',
  '냉장고': 'Fridge',
  '냉동고': 'Freezer',
  '1인분': '1 serving',
  '2인분': '2 servings',
  '3인분': '3 servings',
  '4인분': '4 servings',
  '초급요리사': 'Novice Chef',
  '중급요리사': 'Home Chef',
  '요리 새싹': 'Cooking Sprout',
  'K-Food 도전 중': 'K-Food In Progress',
  'K-FOOD 마스터': 'K-FOOD Master',
  '남성': 'Male',
  '여성': 'Female',
  '선택 안 함': 'Not specified',
  '비공개': 'Private',
};

/// 카탈로그 category('채소'/'수산')와 냉장고 세부분류('야채'/'생선')가 같은 개념을
/// 다른 말로 저장하고 있어서, 화면에 보여줄 때만 세부분류 쪽 표기('야채'/'생선')로
/// 통일한다. 필터링/DB에 쓰이는 원본 값(row.category, ingredients.category 등)은 안 바꾼다.
const _koDisplayOverrides = {
  '채소': '야채',
  '수산': '생선',
};

/// 난이도/요리종류/조리시간 등 데이터에서 온 짧은 한글 태그를 영어로 표시한다.
/// (필터링에 쓰이는 원본 한글 값 자체는 바꾸지 않는다)
String trTag(String ko) =>
    tr(_koDisplayOverrides[ko] ?? ko, _tagDictionary[ko] ?? ko);

/// "N인분" 같은 인분 표시를 언어에 맞게 변환한다.
String trServings(int n) => tr('$n인분', n == 1 ? '1 serving' : '$n servings');
