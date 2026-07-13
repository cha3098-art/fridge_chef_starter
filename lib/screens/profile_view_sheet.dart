import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

/// 게시판/랭킹에서 아이디를 눌렀을 때 뜨는 프로필 보기 — 비공개 항목은 "비공개"로 가려진다.
Future<void> showProfileView(BuildContext context, UserProfile profile) {
  final view = profile.toPublicView();
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFFFFFFFF),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipOval(
              child: Container(
                width: 84,
                height: 84,
                color: AppColors.paperDeep,
                child: view.photoPath == null
                    ? const Icon(Icons.person, size: 36, color: AppColors.inkSoft)
                    : Image.file(File(view.photoPath!), fit: BoxFit.cover, width: 84, height: 84),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(view.nickname, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ),
          Center(
            child: Text('@${view.id}', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ),
          const SizedBox(height: 16),
          _ProfileRow(label: tr('성별', 'Gender'), value: view.gender),
          _ProfileRow(label: tr('국적', 'Nationality'), value: view.nationality),
          _ProfileRow(label: tr('거주도시', 'City'), value: view.city),
          _ProfileRow(label: tr('이메일', 'Email'), value: view.email),
          if (view.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr('자기소개', 'Bio'), style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
            const SizedBox(height: 4),
            Text(view.bio, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isPrivate = value == '비공개';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ),
          Expanded(
            child: Row(
              children: [
                if (isPrivate) const Icon(Icons.lock_outline, size: 12, color: AppColors.inkSoft),
                if (isPrivate) const SizedBox(width: 4),
                Text(
                  trTag(value),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPrivate ? AppColors.inkSoft : AppColors.ink,
                    fontStyle: isPrivate ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
