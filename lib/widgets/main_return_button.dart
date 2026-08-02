import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_theme.dart';

/// 메인 대시보드로 돌아가는 플로팅 버튼 — main_dashboard_screen.dart의 "SNS공유" 배지와
/// 같은 톤(흰 배경 + 그린 테두리 + 그린 틴트 섀도우)의 캡슐형 버튼.
/// 메인 화면을 제외한 화면에서 floatingActionButton으로 붙여 쓴다.
class MainReturnButton extends StatelessWidget {
  const MainReturnButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.green, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_rounded, size: 16, color: AppColors.greenDeep),
            const SizedBox(width: 6),
            Text(
              tr('Main 돌아가기', 'Back to Main'),
              style: const TextStyle(
                  color: AppColors.greenDeep, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
