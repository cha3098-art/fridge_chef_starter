import 'package:flutter/material.dart';

/// 사진 업로드 영역 바로 아래에 두는 무료 AI 이미지 가이드 캡션 바.
/// 유료 이미지 생성 API 없이, 사용자가 Bing Image Creator/MS Copilot(둘 다 무료)로
/// 직접 요리 사진·단계별 그림을 만들어 올릴 수 있도록 안내한다.
class AiImageGuideBanner extends StatelessWidget {
  const AiImageGuideBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Text(
        '💡 팁: 요리 사진이나 단계별 그림이 필요하신가요? Bing Image Creator나 MS Copilot(무료)에 '
        "'단계별 요리 과정'을 입력하면 먹음직스러운 AI 요리 그림을 만들어 올릴 수 있어요!",
        style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.5),
      ),
    );
  }
}
