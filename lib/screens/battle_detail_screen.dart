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

  String? get _myUid => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
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

    setState(() => _busy = true);
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 88);
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }
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
          photoUrl: url);
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
                        ],
                      ),
                    ),
    );
  }

  Widget _actionButton(
      {required String label, required VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: onPressed,
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    final canVote =
        battle.status == BattleStatus.voting && participant.userId != _myUid;

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
          const SizedBox(height: 10),
          if (battle.status == BattleStatus.voting ||
              battle.status == BattleStatus.completed)
            Text('🗳️ $voteCount',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
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
                  iVotedThis ? tr('투표함', 'Voted') : tr('투표하기', 'Vote'),
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
    final deadline = battle.votingEndsAt;
    final remaining = battle.status == BattleStatus.voting && deadline != null
        ? deadline.difference(DateTime.now())
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
                  ? tr('곧 자동으로 마감돼요', 'Closing automatically any moment now')
                  : remaining.inHours >= 1
                      ? tr('${remaining.inHours}시간 후 자동 마감',
                          'Closes automatically in ${remaining.inHours}h')
                      : tr('${remaining.inMinutes}분 후 자동 마감',
                          'Closes automatically in ${remaining.inMinutes}m'),
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
