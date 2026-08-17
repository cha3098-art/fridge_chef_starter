import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/tr.dart';
import '../models/battle.dart';
import '../models/battle_participant.dart';
import '../services/battle_store.dart';
import '../services/chef_points_store.dart';
import '../theme/app_theme.dart';
import '../theme/battle_avatars.dart';
import '../utils/battle_countdown.dart';
import '../utils/image_compressor.dart';
import '../widgets/battle_banner_image.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/main_return_button.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/mascot_image_fallback.dart';

/// 배틀 상세 화면 — 초대 링크(https://fridgechef.app/battle/{id})로도 진입한다.
/// 참가/사진 제출/투표/승자 확정까지 이 한 화면에서 상태에 따라 다르게 보여준다.
class BattleDetailScreen extends StatefulWidget {
  final String battleId;
  /// 목록에서 넘어올 때의 리스트 인덱스 — 카드에 쓰인 것과 같은 VS 배너 이미지를
  /// 상세 화면에서도 그대로 보여주기 위함. null이면(딥링크 등 목록 없이 진입) battleId를
  /// 해시해서 안정적으로 하나를 고른다.
  final int? bannerIndex;
  const BattleDetailScreen({super.key, required this.battleId, this.bannerIndex});

  @override
  State<BattleDetailScreen> createState() => _BattleDetailScreenState();
}

class _BattleDetailScreenState extends State<BattleDetailScreen> {
  Battle? _battle;
  List<BattleParticipant> _participants = [];
  Map<String, int> _voteCounts = {};
  String? _myVoteParticipantId;
  Map<String, String> _nicknames = {};
  Map<String, String?> _genders = {};
  bool _loaded = false;
  bool _busy = false;
  String? _errorMessage;
  RealtimeChannel? _votesChannel;

  String? get _myUid => Supabase.instance.client.auth.currentUser?.id;
  int get _bannerIndex => widget.bannerIndex ?? widget.battleId.hashCode.abs();

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeVotes();
  }

  void _subscribeVotes() {
    _votesChannel = Supabase.instance.client
        .channel('battle_votes_${widget.battleId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_votes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'battle_id',
            value: widget.battleId,
          ),
          callback: (_) => _refreshVoteCounts(),
        )
        .subscribe();
  }

  Future<void> _refreshVoteCounts() async {
    if (_participants.isEmpty) return;
    try {
      final votes = await BattleStore.instance.fetchVotes(widget.battleId);
      final tally = <String, int>{for (final p in _participants) p.id: 0};
      for (final v in votes) {
        tally[v.votedForParticipantId] =
            (tally[v.votedForParticipantId] ?? 0) + 1;
      }
      final myVote = votes
          .where((v) => v.voterId == _myUid)
          .map((v) => v.votedForParticipantId)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _voteCounts = tally;
        _myVoteParticipantId = myVote;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _votesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      await _loadInner();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = tr('배틀 정보를 불러오지 못했어요', 'Could not load this battle');
        _loaded = true;
      });
    }
  }

  Future<void> _loadInner() async {
    final battle = await BattleStore.instance.fetchBattle(widget.battleId);
    if (battle == null) {
      if (!mounted) return;
      setState(() => _loaded = true);
      return;
    }
    final participants =
        await BattleStore.instance.fetchParticipants(widget.battleId);
    final votes = await BattleStore.instance.fetchVotes(widget.battleId);
    final userIds = participants.map((p) => p.userId).toList();
    final nicknames = await BattleStore.instance.fetchNicknames(userIds);
    final genders = await BattleStore.instance.fetchGenders(userIds);

    final tally = <String, int>{for (final p in participants) p.id: 0};
    for (final v in votes) {
      tally[v.votedForParticipantId] =
          (tally[v.votedForParticipantId] ?? 0) + 1;
    }
    final myVote = votes
        .where((v) => v.voterId == _myUid)
        .map((v) => v.votedForParticipantId)
        .firstOrNull;

    // 완료된 배틀의 승자가 바로 나라면, 배틀당 1회로 중복 방지된 포인트를 적립한다
    // (호스트가 대신 상대에게 포인트를 줄 수 없으므로 — 승자 본인이 화면을 열 때만 반영됨).
    if (battle.status == BattleStatus.completed &&
        battle.winnerUserId == _myUid) {
      final winnerParticipant =
          participants.where((p) => p.userId == _myUid).firstOrNull;
      final opponent =
          participants.where((p) => p.userId != _myUid).firstOrNull;
      if (winnerParticipant != null) {
        await ChefPointsStore.instance.recordBattleWin(
          battleId: battle.id,
          opponentLabel: opponent == null
              ? tr('상대', 'opponent')
              : (nicknames[opponent.userId] ?? tr('상대', 'opponent')),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _battle = battle;
      _participants = participants;
      _voteCounts = tally;
      _myVoteParticipantId = myVote;
      _nicknames = nicknames;
      _genders = genders;
      _loaded = true;
    });
  }

  BattleParticipant? get _hostParticipant => _participants
      .where((p) => p.role == BattleParticipantRole.host)
      .firstOrNull;
  BattleParticipant? get _opponentParticipant => _participants
      .where((p) => p.role == BattleParticipantRole.opponent)
      .firstOrNull;
  BattleParticipant? get _myParticipant =>
      _participants.where((p) => p.userId == _myUid).firstOrNull;
  bool get _isHost => _battle?.hostUserId == _myUid;

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await BattleStore.instance.joinBattle(widget.battleId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('참가에 실패했어요 (이미 상대가 있을 수 있어요)',
                'Could not join (opponent slot may be taken)'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPhoto() async {
    final participant = _myParticipant;
    if (participant == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.green),
              title: Text(tr('카메라로 촬영', 'Take a photo')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.green),
              title: Text(tr('갤러리에서 선택', 'Choose from gallery')),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    if (picked == null || !mounted) return;

    // 이미지 피커(카메라/갤러리)가 시스템 액티비티를 열었다 닫으면서 위젯 트리가 아직
    // 자리를 못 잡은 채로 바로 다이얼로그를 띄우면 Flutter 프레임워크 내부에서
    // "_dependents.isEmpty" assertion이 튀는 경우가 있다(붉은 에러 화면). 실제 제출
    // 자체는 이어서 정상 진행되지만 화면이 잠깐 깨져 보이므로, 한 프레임 이상 쉬어서
    // 트리가 안정된 뒤에 다이얼로그를 연다.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final comment = await _promptForComment();
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final compressedFile =
          await ImageCompressor.compressImage(File(picked.path));
      final bytes = await compressedFile.readAsBytes();
      final ext = compressedFile.path.contains('.')
          ? compressedFile.path.split('.').last.toLowerCase()
          : 'jpg';
      final url =
          await BattleStore.instance.uploadBattlePhoto(bytes, fileExt: ext);
      await BattleStore.instance.submitPhoto(
          battleId: widget.battleId,
          participantId: participant.id,
          photoUrl: url,
          comment: comment);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(tr('사진 제출에 실패했어요', 'Could not submit the photo'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 사진과 함께 남길 짧은 한마디(최대 200자)를 물어본다. 건너뛰기를 누르면 null.
  Future<String?> _promptForComment() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('한마디 남기기 (선택)', 'Say something (optional)'),
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.ink)),
        content: TextField(
          controller: controller,
          maxLength: battleCommentMaxLength,
          maxLines: 3,
          style: const TextStyle(color: AppColors.ink),
          decoration: InputDecoration(
            hintText: tr(
                '요리하면서 있었던 일을 짧게 남겨보세요', 'Share a quick note about your dish'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: Text(tr('건너뛰기', 'Skip'),
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(tr('완료', 'Done'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _vote(String participantId) async {
    setState(() => _busy = true);
    try {
      await BattleStore.instance
          .vote(battleId: widget.battleId, participantId: participantId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('투표에 실패했어요', 'Could not submit the vote'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyInviteLink() async {
    final link = _battle?.inviteLink;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('초대 링크를 복사했어요', 'Invite link copied'))),
    );
  }

  Future<void> _finalize() async {
    setState(() => _busy = true);
    try {
      await BattleStore.instance.finalizeBattle(widget.battleId);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('배틀을 포기할까요?', 'Give up this battle?')),
        content: Text(tr('상대에게도 알림이 가고, 이 배틀은 취소돼요.',
            "Your opponent will be notified and this battle will be cancelled.")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('아니요', 'No')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('포기하기', 'Give up'),
                style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await BattleStore.instance.cancelBattle(widget.battleId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('취소에 실패했어요', 'Could not cancel'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    return Scaffold(
      backgroundColor: AppColors.paper,
      floatingActionButton: Padding(
        padding:
            EdgeInsets.only(bottom: 95 + MediaQuery.of(context).padding.bottom),
        child: const MainReturnButton(),
      ),
      appBar: AppBar(
        leading: const LabeledBackButton(),
        leadingWidth: 96,
        backgroundColor: AppColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(battle?.themeTitle ?? tr('배틀', 'Battle'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (battle?.inviteLink != null)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: AppColors.ink),
              onPressed: _copyInviteLink,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FridgeMascot(size: 84),
                      const SizedBox(height: AppSpacing.md),
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppColors.red)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: _load,
                          child: Text(tr('다시 시도', 'Try again'))),
                    ],
                  ),
                )
              : battle == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FridgeMascot(size: 84),
                          const SizedBox(height: AppSpacing.md),
                          Text(tr('배틀을 찾을 수 없어요', "Couldn't find this battle"),
                              style: const TextStyle(color: AppColors.inkSoft)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        children: [
                          if (battle.status != BattleStatus.cancelled) ...[
                            // 배틀 사진(VS 배너)은 좌우 여백 없이 화면 폭에 꽉 차게 배치한다.
                            BattleBannerImage(index: _bannerIndex, height: 165),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            child: Column(
                              children: [
                                _StatusBanner(battle: battle),
                                if (battle.status == BattleStatus.submitted ||
                                    battle.status == BattleStatus.voting ||
                                    battle.status ==
                                        BattleStatus.completed) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _TugOfWarBar(
                                    hostVotes:
                                        _voteCounts[_hostParticipant?.id] ?? 0,
                                    challengerVotes: _voteCounts[
                                            _opponentParticipant?.id] ??
                                        0,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: _buildParticipantCard(
                                            _hostParticipant,
                                            isHostSlot: true)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        child: _buildParticipantCard(
                                            _opponentParticipant,
                                            isHostSlot: false)),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (_opponentParticipant == null &&
                                    !_isHost &&
                                    _myParticipant == null)
                                  _actionButton(
                                    label: tr('배틀 참가하기', 'Join battle'),
                                    onPressed: _busy ? null : _join,
                                  ),
                                if (_myParticipant != null &&
                                    !_myParticipant!.hasSubmitted &&
                                    battle.status != BattleStatus.completed &&
                                    battle.status != BattleStatus.cancelled)
                                  _actionButton(
                                    label: tr(
                                        '완성 사진 제출하기', 'Submit finished photo'),
                                    onPressed: _busy ? null : _submitPhoto,
                                  ),
                                if (_isHost &&
                                    battle.status == BattleStatus.voting)
                                  _actionButton(
                                    label: tr('투표 마감하고 승자 확정',
                                        'Close voting & pick winner'),
                                    onPressed: _busy ? null : _finalize,
                                  ),
                                if (_myParticipant != null &&
                                    (battle.status ==
                                            BattleStatus.waitingOpponent ||
                                        battle.status ==
                                            BattleStatus.submitted))
                                  _actionButton(
                                    label: _opponentParticipant == null
                                        ? tr('초대 취소', 'Cancel invite')
                                        : tr('배틀 포기', 'Give up'),
                                    onPressed: _busy ? null : _cancel,
                                    isDestructive: true,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _actionButton(
      {required String label,
      required VoidCallback? onPressed,
      bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: isDestructive
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: onPressed == null
                      ? null
                      : [
                          BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                ),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.red, width: 1.5),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onPressed,
                  child: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              )
            // 최하단 메인 CTA까지 민트색이면 화면 위아래가 온통 민트로 붕 뜬다 —
            // 다크 슬레이트 톤으로 화면 전체의 무게감/균형을 잡는다.
            : _PillShadowButton(
                color: AppColors.ink,
                onPressed: onPressed,
                label: label,
              ),
      ),
    );
  }

  Widget _buildParticipantCard(BattleParticipant? participant,
      {required bool isHostSlot}) {
    final battle = _battle!;
    final roleLabel = isHostSlot ? tr('호스트', 'Host') : tr('상대', 'Opponent');
    final sideColor = isHostSlot ? AppColors.tealPrimary : AppColors.carrot;
    if (participant == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: cardDecoration(radius: 20),
        child: Column(
          children: [
            Text(roleLabel,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            const Icon(Icons.person_outline,
                size: 40, color: AppColors.inkSoft),
            const SizedBox(height: 8),
            Text(tr('대기 중', 'Waiting'),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ),
      );
    }

    final nickname = _nicknames[participant.userId] ?? tr('냉장고 셰프', 'Chef');
    final avatarAsset =
        battleAvatarFor(participant.userId, _genders[participant.userId]);
    final isWinner = battle.status == BattleStatus.completed &&
        battle.winnerUserId == participant.userId;
    final iVotedThis = _myVoteParticipantId == participant.id;
    // 매칭이 성사된 순간(status=submitted)부터 배틀이 끝나기 전까지는 본인을 제외한
    // 누구나 투표할 수 있다 — 사진 제출 여부와 무관하다.
    final canVote = (battle.status == BattleStatus.submitted ||
            battle.status == BattleStatus.voting) &&
        participant.userId != _myUid;

    final isMine = participant.userId == _myUid;
    final canSubmitHere = isMine &&
        !participant.hasSubmitted &&
        battle.status != BattleStatus.completed &&
        battle.status != BattleStatus.cancelled;

    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: isWinner ? Border.all(color: AppColors.gold, width: 2) : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isWinner) const Text('👑 ', style: TextStyle(fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sideColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(roleLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sideColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 완성작 전시 프레임 — 세로 비율(0.85)의 깔끔한 라운드 프레임으로 통일하고,
          // 사진이 아직 없으면 점선 테두리의 제출 유도 버튼을, 있으면 실제 음식 사진을
          // 보여준다. 아바타+닉네임은 사진 위에 얹는 글래스모피즘 칩으로 이동.
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 0.85,
                  child: participant.photoPath != null
                      ? Image.network(
                          participant.photoPath!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: AppColors.paperDeep,
                              alignment: Alignment.center,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2.5),
                            );
                          },
                          errorBuilder: (context, error, stack) =>
                              const RoundedMascotFallback(),
                        )
                      : _SubmitPhotoPlaceholder(
                          canSubmit: canSubmitHere,
                          onTap: canSubmitHere ? _submitPhoto : null,
                        ),
                ),
              ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: _GlassInfoChip(
                    avatarAsset: avatarAsset, nickname: nickname),
              ),
              if (isWinner)
                const Positioned(
                  top: -6,
                  left: 0,
                  right: 0,
                  child: Center(child: _WinnerRibbon()),
                ),
            ],
          ),
          if (participant.comment != null &&
              participant.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              participant.comment!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSoft, height: 1.4),
            ),
          ],
          if (canVote) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: iVotedThis
                  // 이미 투표한 카드까지 쨍한 면 채우기로 강조하면 화면이 온통 색으로
                  // 도배되어 산만해진다 — 소프트 틴트 배경 + 얇은 테두리로 톤을 낮춘다.
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: sideColor,
                        backgroundColor: sideColor.withValues(alpha: 0.12),
                        side: BorderSide(color: sideColor, width: 1.5),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: null,
                      child: Text(tr('투표함 ✓', 'Voted ✓'),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                    )
                  : _PillShadowButton(
                      color: sideColor,
                      onPressed: _busy ? null : () => _vote(participant.id),
                      label: tr('투표하기', 'Vote'),
                    ),
            ),
          ],
        ],
      ),
    );

    if (!isWinner) return card;
    return _PulseGlow(color: AppColors.gold, child: card);
  }
}

/// 소프트 섀도우 + 굵은 폰트의 알약(pill) 버튼 — 투표/제출 등 주요 액션에 쓴다.
class _PillShadowButton extends StatelessWidget {
  final Color color;
  final String label;
  final VoidCallback? onPressed;
  const _PillShadowButton(
      {required this.color, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// 완성 사진이 아직 없을 때 보여주는 자리표시자 — 소프트 민트 그라데이션 배경 +
/// 은은하게 빛나는 카메라 아이콘. 내 참가자 카드라면 탭해서 바로 사진 제출로 들어간다.
class _SubmitPhotoPlaceholder extends StatelessWidget {
  final bool canSubmit;
  final VoidCallback? onTap;
  const _SubmitPhotoPlaceholder({required this.canSubmit, this.onTap});

  @override
  Widget build(BuildContext context) {
    // 이 카드가 민트로 진하게 물들면 정작 옆의 실제 요리 사진보다 시선을 더 끌어버린다
    // — 옅은 오프화이트 배경 + 미세한 테두리 선으로 톤을 낮추고, 존재감은 카메라
    // 아이콘의 작은 글로우 정도로만 남긴다.
    final content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.paper,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card,
                boxShadow: canSubmit
                    ? [
                        BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 1),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.camera_alt_outlined,
                  size: 26,
                  color: canSubmit ? AppColors.green : AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            Text(
              canSubmit
                  ? tr('📸 완성된 요리\n사진 올리기', '📸 Upload your\nfinished dish')
                  : tr('요리 준비 중...🔥', 'Cooking...🔥'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: canSubmit ? AppColors.greenDeep : AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap, child: content);
  }
}

/// 사진 하단에 얹는 글래스모피즘(반투명 블러) 칩 — 마스코트 아바타 + 닉네임을
/// 보여줘서 "이게 누구 요리인지" 사진 위에서 바로 알아볼 수 있게 한다.
class _GlassInfoChip extends StatelessWidget {
  final String avatarAsset;
  final String nickname;
  const _GlassInfoChip({required this.avatarAsset, required this.nickname});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                  image: DecorationImage(
                      image: AssetImage(avatarAsset), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(nickname,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 승자 카드 상단에 살짝 기울여 얹는 입체적인 골드 리본 배지.
class _WinnerRibbon extends StatelessWidget {
  const _WinnerRibbon();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [AppColors.gold, Color(0xFFFFE08A)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.7), blurRadius: 12),
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
          ],
        ),
        child: Text(tr('🎉 승리 🏆', 'WINNER 🏆'),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.ink)),
      ),
    );
  }
}

/// 승자 카드를 은은하게 계속 반짝이게 만드는 골드 글로우 래퍼
class _PulseGlow extends StatefulWidget {
  final Color color;
  final Widget child;
  const _PulseGlow({required this.color, required this.child});

  @override
  State<_PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<_PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final blur = 10 + _controller.value * 14;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withValues(alpha: 0.55),
                  blurRadius: blur),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 두 참가자의 득표율이 서로 밀고 당기는 통합 대결 게이지 바.
/// 왼쪽(민트)=호스트, 오른쪽(카로트오렌지)=상대. 숫자가 바뀔 때마다 팝 애니메이션.
class _TugOfWarBar extends StatelessWidget {
  final int hostVotes;
  final int challengerVotes;

  const _TugOfWarBar({required this.hostVotes, required this.challengerVotes});

  @override
  Widget build(BuildContext context) {
    final total = hostVotes + challengerVotes;
    final hostRatio = total == 0 ? 0.0 : hostVotes / total;
    final hostPct = total == 0 ? 0 : (hostRatio * 100).round();
    final challengerPct = total == 0 ? 0 : 100 - hostPct;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: cardDecoration(radius: AppSpacing.radiusMd),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _VoteSideLabel(
                  pct: hostPct, count: hostVotes, color: AppColors.tealPrimary),
              Text(tr('🗳️ 실시간 득표', '🗳️ Live Votes'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft)),
              _VoteSideLabel(
                  pct: challengerPct,
                  count: challengerVotes,
                  color: AppColors.carrot,
                  alignEnd: true),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 26,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  // 득표가 없으면 차분한 Cool Grey 트랙만 보여주고, 득표가 생기면
                  // 그때부터 host(민트)/opponent(캐롯)가 각자 비율만큼 양쪽에서 채워진다.
                  return Stack(
                    children: [
                      Container(width: w, color: const Color(0xFFE2E8F0)),
                      if (total > 0) ...[
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            width: w * hostRatio,
                            color: AppColors.tealPrimary,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            width: w * (1 - hostRatio),
                            color: AppColors.carrot,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 득표 측 라벨 — 퍼센트(볼드, 팝 애니메이션)와 표 수를 함께 보여준다.
class _VoteSideLabel extends StatelessWidget {
  final int pct;
  final int count;
  final Color color;
  final bool alignEnd;
  const _VoteSideLabel(
      {required this.pct,
      required this.count,
      required this.color,
      this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: 1.4, end: 1.0)
                .chain(CurveTween(curve: Curves.elasticOut))
                .animate(animation),
            child: child,
          ),
          child: Text(
            '$pct%',
            key: ValueKey(pct),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
        ),
        Text('($count${tr('표', count == 1 ? ' vote' : ' votes')})',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: 0.85))),
      ],
    );
  }
}

// ── 상태 배너 (VS 글로우 배지 + 불꽃 타이머) ────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Battle battle;
  const _StatusBanner({required this.battle});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (battle.status) {
      BattleStatus.waitingOpponent => (
          tr('상대를 기다리고 있어요', 'Waiting for an opponent'),
          AppColors.inkSoft
        ),
      BattleStatus.submitted => (
          tr('완성 사진을 제출해주세요', 'Submit your finished dish'),
          AppColors.carrot
        ),
      BattleStatus.voting => (
          tr('투표가 진행 중이에요', 'Voting is open'),
          AppColors.gold
        ),
      BattleStatus.completed => (
          tr('배틀이 종료됐어요', 'Battle finished'),
          AppColors.green
        ),
      BattleStatus.cancelled => (
          tr('배틀이 취소됐어요', 'Battle cancelled'),
          AppColors.red
        ),
    };
    final isSubmissionPhase = battle.status == BattleStatus.submitted;
    final isWaitingPhase = battle.status == BattleStatus.waitingOpponent;
    final isVotingPhase = battle.status == BattleStatus.voting;

    // 제출 마감(3시간)은 기존 문구를 그대로 쓰고, 매칭 대기(1일)·투표 종료(2일)는
    // formatBattleCountdown으로 "N일 N시간 남음" 형태를 공유한다.
    final Duration? remaining = isSubmissionPhase
        ? battle.submissionDeadline?.difference(DateTime.now())
        : isWaitingPhase
            ? battle.createdAt
                .add(const Duration(days: 1))
                .difference(DateTime.now())
            : isVotingPhase
                ? battle.votingEndsAt?.difference(DateTime.now())
                : null;
    // 진행률 바 계산용 각 단계의 총 길이 — 실제 자동 마감 정책(3시간/1일/2일)과 동일하게 맞춘다.
    final Duration? totalForPhase = isSubmissionPhase
        ? const Duration(hours: 3)
        : isWaitingPhase
            ? const Duration(days: 1)
            : isVotingPhase
                ? const Duration(days: 2)
                : null;

    final phaseKeyword = switch (battle.status) {
      BattleStatus.waitingOpponent => tr('🙋 상대 찾는 중', '🙋 FINDING OPPONENT'),
      BattleStatus.submitted => tr('📸 지금 제출하세요', '📸 SUBMIT NOW'),
      BattleStatus.voting => tr('🔥 실시간 투표 중', '🔥 LIVE VOTING'),
      _ => '',
    };

    // 위쪽에 이미 VS 배너 이미지(BattleBannerImage)가 대결 구도를 보여주므로,
    // 여기는 순수 화이트 배경 위에 안내 문구 + 타이머 캡슐만 컴팩트하게 정리한다
    // — 탁한 파스텔 카드 배경은 쓰지 않는다.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          if (remaining != null && totalForPhase != null) ...[
            const SizedBox(height: 10),
            _LiveStatusPill(
              text: remaining.isNegative
                  ? tr('곧 자동 처리돼요', 'Closing any moment')
                  : '$phaseKeyword · ${formatBattleCountdown(remaining)}',
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

/// "🔥 LIVE VOTING · 23h 45m left" 형태의 캡슐형 네온 상태 바.
class _LiveStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _LiveStatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    // "다크 민트/카로트" 캡슐 — 진한 잉크 베이스에 단계별 포인트 컬러를 살짝 섞어
    // 순수 검정이 아니라 은은하게 그 색을 머금은 다크 톤으로 보이게 한다.
    final darkTinted = Color.lerp(AppColors.ink, color, 0.22)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: darkTinted,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color, width: 1.4),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12),
        ],
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: 0.2)),
    );
  }
}
