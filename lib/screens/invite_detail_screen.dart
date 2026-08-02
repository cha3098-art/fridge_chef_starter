import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/recipe_catalog.dart';
import '../l10n/tr.dart';
import '../models/meal_invite.dart';
import '../services/meal_invite_store.dart';
import '../theme/app_theme.dart';
import '../theme/food_visuals.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/main_return_button.dart';
import 'recipe_detail_screen.dart';

String _timeAgoLabel(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return tr('방금 전', 'just now');
  if (diff.inHours < 1) return tr('${diff.inMinutes}분 전', '${diff.inMinutes}m ago');
  if (diff.inDays < 1) return tr('${diff.inHours}시간 전', '${diff.inHours}h ago');
  return tr('${diff.inDays}일 전', '${diff.inDays}d ago');
}

/// 카드 안 구획 사이에 넣는 장식용 구분선 — share_screen.dart의 _OrnamentDivider와 동일한
/// 톤(얇은 실선 + 가운데 골드 다이아 포인트)을 이 파일에서도 그대로 쓴다.
class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(width: 6, height: 6, color: const Color(0xFFCBB273)),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
        ],
      ),
    );
  }
}

/// 딥링크(https://fridgechef.app/invite/{id})로 진입했을 때 보여주는 초대장 상세 화면.
/// 로그인 여부와 무관하게 누구나 열어볼 수 있다 (meal_invites의 select RLS가 전체 공개).
class InviteDetailScreen extends StatefulWidget {
  final String inviteId;
  const InviteDetailScreen({super.key, required this.inviteId});

  @override
  State<InviteDetailScreen> createState() => _InviteDetailScreenState();
}

class _InviteDetailScreenState extends State<InviteDetailScreen> {
  late final Future<MealInvite?> _inviteFuture = MealInviteStore.instance.fetchInvite(widget.inviteId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const MainReturnButton(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFCBD9EA), Color(0xFFE4EAE3)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: Row(
                  children: [
                    const LabeledBackButton(color: Color(0xFF0F172A)),
                    const SizedBox(width: 10),
                    Text(tr('식사 초대장', 'Meal Invite'),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<MealInvite?>(
                  future: _inviteFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final invite = snapshot.data;
                    if (invite == null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FridgeMascot(size: 84),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              tr('초대장을 찾을 수 없어요', "Couldn't find this invite"),
                              style: const TextStyle(color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                      );
                    }

                    final recipe = findRecipeByTitle(invite.recipeTitle);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF8),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 28,
                                offset: const Offset(0, 12)),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // 상단 워터컬러풍 헤더 밴드 — 요리자랑 상세와 동일한 톤
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFEFF3E8), Color(0xFFDCE7EF)],
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    tr('식사 초대', 'MEAL INVITATION'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 3,
                                      color: Color(0xFF6B7A6E),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    invite.recipeTitle,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.notoSerifKr(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      color: const Color(0xFF1E2A22),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tr('${invite.hostNickname}님의 초대 · ${_timeAgoLabel(invite.createdAt)}',
                                        'Invited by ${invite.hostNickname} · ${_timeAgoLabel(invite.createdAt)}'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF7C8A7F)),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 본문 메시지
                                  Text(
                                    invite.message.isNotEmpty
                                        ? invite.message
                                        : tr('같이 만들어 먹어요!', "Let's cook together!"),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.notoSerifKr(
                                      fontSize: 15,
                                      height: 1.8,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  const _OrnamentDivider(),

                                  // 첨부 사진
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: RecipePhoto(
                                        photoUrl: recipe?.photoUrl ??
                                            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Bibimbap_7.jpg/960px-Bibimbap_7.jpg',
                                        emoji: recipe?.emoji ?? '🍽️',
                                        cuisineType: recipe?.cuisineType ?? '',
                                        width: double.infinity,
                                        height: 200,
                                        emojiSize: 44,
                                      ),
                                    ),
                                  ),
                                  const _OrnamentDivider(),

                                  // 링크 공유 & 레시피 보기
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F1E7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            invite.inviteLink,
                                            style: const TextStyle(
                                                fontSize: 12, color: Color(0xFF7C8A7F), fontFamily: 'Courier'),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () async {
                                            await Clipboard.setData(ClipboardData(text: invite.inviteLink));
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(tr('링크가 복사됐어요', 'Link copied'))),
                                              );
                                            }
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(Icons.copy_rounded, size: 16, color: AppColors.greenDeep),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (recipe != null) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                        ),
                                        onPressed: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => RecipeDetailScreen(
                                              recipe: recipe,
                                              fridgeIngredientNames: const {},
                                              servings: 1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          tr('레시피 보러 가기', 'View Recipe'),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
