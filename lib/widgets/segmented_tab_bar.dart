import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 대분류 화면 상단의 1차 세그먼트 컨트롤 — 냉장고관리|재료등록 같은 하위 콘텐츠를
/// 즉시 전환한다. 딥 틸(AppColors.tealPrimary) 활성 색으로 2차 필 토글(PillToggle)과
/// 시각적으로 명확히 구분되는, 디자인 스펙에서 지정한 정확한 규격을 따른다:
/// height 44 / track #F1F5F9 / radius 10 / padding 4 / active #0F766E + 얕은 그림자.
class SegmentedTabBar extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SegmentedTabBar(
      {super.key, required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.tealPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2)),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? Colors.white : AppColors.textSub,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 2차 세그먼트 탭(예: 내 배틀|전체 배틀, 전체 랭킹|명예의 전당) — 1차 탭과 다른
/// '알약(pill) 테두리 버튼' 스타일. 기본(outlined=false): 활성 시 다크 슬레이트(#1E293B)
/// 채움 + 흰 글자. outlined=true(배틀 화면 전용): 배경은 항상 흰색이고, 활성 시 테두리/
/// 글자만 activeColor(기본 브랜드 틸 #0F766E)로 바뀌는 더 가벼운 알약 스타일.
/// 비활성 공통: 흰 배경 + 연회색 테두리(#CBD5E1) + 서브 텍스트색.
class PillToggle extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool outlined;
  final Color activeColor;

  const PillToggle({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.outlined = false,
    this.activeColor = AppColors.tealPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final selected = i == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !outlined && selected ? AppColors.pillActive : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: selected
                      ? (outlined ? Border.all(color: activeColor, width: 1.5) : null)
                      : Border.all(color: AppColors.pillBorder, width: 1),
                ),
                child: Text(
                  labels[i],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (outlined ? activeColor : Colors.white)
                        : AppColors.textSub,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
