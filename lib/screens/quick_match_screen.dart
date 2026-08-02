import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../services/battle_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fridge_mascot.dart';
import '../widgets/labeled_back_button.dart';
import '../widgets/main_return_button.dart';
import 'battle_detail_screen.dart';

/// 빠른 매칭 대기 화면 — battle_queue에 들어가서 실시간으로 상대가 잡히길 기다린다.
/// 매칭은 DB 트리거가 서버에서 원자적으로 처리하므로, 여기서는 결과를 구독만 한다
/// (가짜 타이머로 매칭된 척하지 않는다 — 실제로 다른 사용자가 대기열에 들어와야 매칭된다).
class QuickMatchScreen extends StatefulWidget {
  const QuickMatchScreen({super.key});

  @override
  State<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends State<QuickMatchScreen> {
  StreamSubscription<String?>? _subscription;
  bool _matched = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startMatching();
  }

  Future<void> _startMatching() async {
    try {
      await BattleStore.instance.joinQueue();
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _errorMessage = tr('매칭 대기열 등록에 실패했어요', 'Could not join matchmaking'));
      return;
    }
    if (!mounted) return;
    _subscription = BattleStore.instance.watchMatchedBattleId().listen(
      (battleId) {
        if (battleId == null || _matched || !mounted) return;
        _matched = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => BattleDetailScreen(battleId: battleId)),
        );
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _errorMessage =
            tr('매칭 상태를 확인하지 못했어요', 'Lost connection to matchmaking'));
      },
    );
  }

  Future<void> _cancel() async {
    await BattleStore.instance.leaveQueue();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (!_matched) BattleStore.instance.leaveQueue();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_matched) BattleStore.instance.leaveQueue();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        floatingActionButton: const MainReturnButton(),
        appBar: AppBar(
          leading: const LabeledBackButton(),
          leadingWidth: 96,
          backgroundColor: AppColors.paper,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(tr('빠른 매칭', 'Quick Match'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null) ...[
                const FridgeMascot(size: 84),
                const SizedBox(height: AppSpacing.md),
                Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.red)),
              ] else ...[
                const SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                      color: AppColors.green, strokeWidth: 3),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  tr('상대를 찾고 있어요...', 'Looking for an opponent...'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('다른 사용자가 매칭에 들어오면 바로 시작돼요',
                      "We'll start as soon as someone else joins"),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton(
                onPressed: _cancel,
                child: Text(tr('취소', 'Cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
