import 'package:flutter/material.dart';

import '../../profile/domain/profile_catalog.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_models.dart';
import 'paper_widgets.dart';

/// 학교/지역 평균 최고점 랭킹 상위 항목을 보여줍니다. 스냅샷은 서버에서 15분마다 갱신됩니다.
class LeaderboardPanel extends StatefulWidget {
  const LeaderboardPanel({
    required this.repository,
    required this.refreshToken,
    this.highlightSchoolId,
    this.highlightRegionCode,
    super.key,
  });

  final TimeAttackLeaderboardRepository repository;

  /// 값이 바뀌면 랭킹을 다시 불러옵니다. (예: 랭크 기록 제출 직후)
  final int refreshToken;
  final String? highlightSchoolId;
  final String? highlightRegionCode;

  @override
  State<LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<LeaderboardPanel> {
  LeaderboardScope _scope = LeaderboardScope.school;
  Future<List<LeaderboardEntry>>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LeaderboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  void _load() {
    setState(() {
      _entries = widget.repository.loadTopEntries(scope: _scope);
    });
  }

  String _entityName(String entityId) {
    return _scope == LeaderboardScope.school
        ? schoolNameFor(entityId)
        : regionNameFor(entityId);
  }

  bool _isMine(String entityId) {
    return _scope == LeaderboardScope.school
        ? entityId == widget.highlightSchoolId
        : entityId == widget.highlightRegionCode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PaperPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('시즌 랭킹', style: theme.textTheme.titleLarge)),
              SegmentedButton<LeaderboardScope>(
                showSelectedIcon: false,
                segments: LeaderboardScope.values
                    .map((scope) => ButtonSegment<LeaderboardScope>(
                        value: scope, label: Text(scope.label)))
                    .toList(growable: false),
                selected: <LeaderboardScope>{_scope},
                onSelectionChanged: (selection) {
                  _scope = selection.first;
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('구성원 최고 점수의 평균으로 순위를 매겨요.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          FutureBuilder<List<LeaderboardEntry>>(
            future: _entries,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4)),
                );
              }
              if (snapshot.hasError) {
                return Text('랭킹을 불러오지 못했어요.',
                    style: theme.textTheme.bodyMedium);
              }
              final entries = snapshot.data ?? const <LeaderboardEntry>[];
              if (entries.isEmpty) {
                return Text('아직 집계된 기록이 없어요. 첫 기록의 주인공이 되어 보세요!',
                    style: theme.textTheme.bodyMedium);
              }
              return Column(
                children: entries
                    .map(
                      (entry) => _LeaderboardRow(
                        entry: entry,
                        name: _entityName(entry.entityId),
                        highlighted: _isMine(entry.entityId),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.name,
    required this.highlighted,
  });

  final LeaderboardEntry entry;
  final String name;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFE7EBDD) : const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9D0C0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('${entry.rank}', style: theme.textTheme.titleLarge),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.bodyLarge),
                Text('${entry.eligibleUsers}명 참여',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Text(entry.score.toStringAsFixed(0),
              style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
