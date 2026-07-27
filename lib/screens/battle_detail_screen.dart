import 'dart:io';

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
import '../utils/battle_countdown.dart';
import '../utils/image_compressor.dart';
import '../widgets/fridge_mascot.dart';



/// 배틀 상세 화면 — 초대 링크(https://fridgechef.app/battle/{id})로도 진입한다.
/// 참가/사진 제출/투표/승자 확정까지 이 한 화면에서 상태에 따라 다르게 보여준다.
class BattleDetailScreen extends StatefulWidget {
  final String battleId;
  const BattleDetailScreen({super.key, required this.battleId});

  @override
  State<BattleDetailScreen> createState() => _BattleDetailScreenState();
}

class _BattleDetailScreenState extends State<BattleDetailScreen> {
  Battle? _battle;
  List<BattleParticipant> _participants = [];
  Map<String, int> _voteCounts = {};
  String? _myVoteParticipantId;
  Map<String, String> _nicknames = {};
  bool _loaded = false;
  bool _busy = false;
  String? _errorMessage;
  RealtimeChannel? _votesChannel;

  String? get _myUid => Supabase.instance.client.auth.currentUser?.id;

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
      final votes =
          await BattleStore.instance.fetchVotes(widget.battleId);
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
    final nicknames = await BattleStore.instance
        .fetchNicknames(participants.map((p) => p.userId).toList());

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
                fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: battleCommentMaxLength,
          maxLines: 3,
          style: const TextStyle(color: AppColors.ink),
          decoration: InputDecoration(
            hintText: tr('요리하면서 있었던 일을 짧게 남겨보세요',
                'Share a quick note about your dish'),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      appBar: AppBar(
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green))
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
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          _StatusBanner(battle: battle),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _buildParticipantCard(_hostParticipant,
                                      isHostSlot: true)),
                              const SizedBox(width: AppSpacing.sm),
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
                              label: tr('완성 사진 제출하기', 'Submit finished photo'),
                              onPressed: _busy ? null : _submitPhoto,
                            ),
                          if (_isHost && battle.status == BattleStatus.voting)
                            _actionButton(
                              label: tr('투표 마감하고 승자 확정',
                                  'Close voting & pick winner'),
                              onPressed: _busy ? null : _finalize,
                            ),
                          if (_myParticipant != null &&
                              (battle.status == BattleStatus.waitingOpponent ||
                                  battle.status == BattleStatus.submitted))
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
        height: 48,
        child: isDestructive
            ? OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onPressed,
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: onPressed,
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
      ),
    );
  }

  Widget _buildParticipantCard(BattleParticipant? participant,
      {required bool isHostSlot}) {
    final battle = _battle!;
    final roleLabel = isHostSlot ? tr('호스트', 'Host') : tr('상대', 'Opponent');
    if (participant == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: cardDecoration(radius: AppSpacing.radiusLg),
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
    final isWinner = battle.status == BattleStatus.completed &&
        battle.winnerUserId == participant.userId;
    final voteCount = _voteCounts[participant.id] ?? 0;
    final iVotedThis = _myVoteParticipantId == participant.id;
    // 매칭이 성사된 순간(status=submitted)부터 배틀이 끝나기 전까지는 본인을 제외한
    // 누구나 투표할 수 있다 — 사진 제출 여부와 무관하다.
    final canVote = (battle.status == BattleStatus.submitted ||
            battle.status == BattleStatus.voting) &&
        participant.userId != _myUid;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
            color: isWinner ? AppColors.gold : AppColors.cardBorder,
            width: isWinner ? 2 : 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isWinner) const Text('🏆 ', style: TextStyle(fontSize: 14)),
              Text(roleLabel,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 4),
          Text(nickname,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: participant.photoPath != null
                ? Image.network(participant.photoPath!,
                    width: double.infinity, height: 120, fit: BoxFit.cover)
                : Container(
                    width: double.infinity,
                    height: 120,
                    color: AppColors.paperDeep,
                    child: const Center(
                        child: Icon(Icons.restaurant_outlined,
                            color: AppColors.inkSoft)),
                  ),
          ),
          if (participant.comment != null && participant.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              participant.comment!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.inkSoft, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          if (battle.status == BattleStatus.submitted ||
              battle.status == BattleStatus.voting ||
              battle.status == BattleStatus.completed) ...[
            const SizedBox(height: 8),
            _VoteBar(
              voteCount: voteCount,
              totalVotes: _voteCounts.values.fold(0, (a, b) => a + b),
              iVotedThis: iVotedThis,
            ),
          ],
          if (canVote) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: iVotedThis ? Colors.white : AppColors.green,
                  backgroundColor:
                      iVotedThis ? AppColors.green : Colors.transparent,
                  side: const BorderSide(color: AppColors.green),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _busy ? null : () => _vote(participant.id),
                child: Text(
                  iVotedThis ? tr('투표함 ✓', 'Voted ✓') : tr('투표하기', 'Vote'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 투표 수 + 프로그레스 바 ──────────────────────────────────────────────────────

class _VoteBar extends StatelessWidget {
  final int voteCount;
  final int totalVotes;
  final bool iVotedThis;

  const _VoteBar({
    required this.voteCount,
    required this.totalVotes,
    required this.iVotedThis,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalVotes > 0 ? voteCount / totalVotes : 0.0;
    final pct = (ratio * 100).round();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🗳️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$voteCount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: iVotedThis ? AppColors.green : AppColors.ink,
                  ),
                ),
              ],
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: iVotedThis ? AppColors.green : AppColors.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.paperDeep,
            color: iVotedThis ? AppColors.green : AppColors.carrot,
          ),
        ),
      ],
    );
  }
}

// ── 상태 배너 ──────────────────────────────────────────────────────────────────

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

    // 제출 마감(3시간)은 기존 문구를 그대로 쓰고, 매칭 대기(1일)·투표 종료(2일)는
    // formatBattleCountdown으로 "N일 N시간 남음" 형태를 공유한다.
    final Duration? remaining = isSubmissionPhase
        ? battle.submissionDeadline?.difference(DateTime.now())
        : isWaitingPhase
            ? battle.createdAt
                .add(const Duration(days: 1))
                .difference(DateTime.now())
            : battle.status == BattleStatus.voting
                ? battle.votingEndsAt?.difference(DateTime.now())
                : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      child: Column(
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          if (remaining != null) ...[
            const SizedBox(height: 4),
            Text(
              remaining.isNegative
                  ? (isSubmissionPhase
                      ? tr('곧 자동으로 기권 처리돼요',
                          'Closing out as a forfeit any moment now')
                      : isWaitingPhase
                          ? tr('곧 자동으로 삭제돼요',
                              'This will be deleted any moment now')
                          : tr('곧 자동으로 마감돼요',
                              'Closing automatically any moment now'))
                  : isSubmissionPhase
                      ? tr('${remaining.inHours}시간 후 미제출 시 자동 기권',
                          'Auto-forfeits if not submitted in ${remaining.inHours}h')
                      : isWaitingPhase
                          ? tr(
                              '${formatBattleCountdown(remaining)} 안에 상대가 없으면 자동 삭제돼요',
                              'Auto-deletes if no one joins within ${formatBattleCountdown(remaining)}')
                          : tr('${formatBattleCountdown(remaining)} 후 자동 마감',
                              'Closes automatically in ${formatBattleCountdown(remaining)}'),
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
