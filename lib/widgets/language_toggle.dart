import 'package:flutter/material.dart';

import '../services/locale_store.dart';
import '../theme/app_theme.dart';

/// 상단 바에 두는 언어 전환 버튼. 누르면 즉시 한글/영어가 바뀐다.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleStore.instance,
      builder: (context, _) {
        final isKorean = LocaleStore.instance.isKorean;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: LocaleStore.instance.toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.paperDeep,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 14, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Text(
                  isKorean ? 'EN' : '한글',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
