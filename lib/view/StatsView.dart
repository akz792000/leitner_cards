import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import 'package:leitner_cards/repository/CardRepository.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: GroupCode.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistics'),
          bottom: TabBar(
            tabs: GroupCode.values
                .map((g) => Tab(text: g.title))
                .toList(),
          ),
        ),
        body: TabBarView(
          children: GroupCode.values
              .map((g) => _StatsTab(groupCode: g))
              .toList(),
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final GroupCode groupCode;

  const _StatsTab({required this.groupCode});

  _StatsData _compute() {
    final repo = Get.find<CardRepository>();
    final cards = repo.findAllByGroupCode(groupCode);

    if (cards.isEmpty) return _StatsData.empty();

    final total = cards.length;
    final started = cards.where((c) => c.level > 0).length;
    final totalReviews = cards.fold<int>(0, (sum, c) => sum + c.order);
    final maxLevel = cards.map((c) => c.level).reduce((a, b) => a > b ? a : b);

    // Level distribution (sorted ascending)
    final levelMap = <int, int>{};
    for (final card in cards) {
      levelMap[card.level] = (levelMap[card.level] ?? 0) + 1;
    }
    final sortedLevels = levelMap.keys.toList()..sort();

    // Recent activity
    final now = DateTimeUtil.now();
    final today = cards.where((c) {
      return c.modified.year == now.year &&
          c.modified.month == now.month &&
          c.modified.day == now.day;
    }).length;

    final lastModified = cards
        .map((c) => c.modified)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return _StatsData(
      total: total,
      started: started,
      totalReviews: totalReviews,
      maxLevel: maxLevel,
      levelMap: levelMap,
      sortedLevels: sortedLevels,
      reviewedToday: today,
      lastModified: lastModified,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _compute();

    if (data.total == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No cards yet for ${groupCode.title}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final progressPercent = data.started / data.total;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              _buildSummaryCard(
                context,
                value: '${data.total}',
                label: 'Total Cards',
                icon: Icons.style_outlined,
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                context,
                value: '${data.totalReviews}',
                label: 'Total Reviews',
                icon: Icons.replay_outlined,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                context,
                value: 'Lvl ${data.maxLevel}',
                label: 'Max Level',
                icon: Icons.emoji_events_outlined,
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Overall progress
          _buildSectionLabel('Overall Progress'),
          const SizedBox(height: 12),
          _buildProgressCard(context, progressPercent, data.started, data.total),

          const SizedBox(height: 24),

          // Level distribution
          _buildSectionLabel('Level Distribution'),
          const SizedBox(height: 12),
          _buildLevelDistribution(context, data),

          const SizedBox(height: 24),

          // Recent activity
          _buildSectionLabel('Recent Activity'),
          const SizedBox(height: 12),
          _buildActivityCard(context, data),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    double percent,
    int started,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$started of $total cards started',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _progressColor(percent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor(percent)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _progressLabel(percent),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Color _progressColor(double percent) {
    if (percent < 0.3) return Colors.red.shade400;
    if (percent < 0.6) return Colors.orange.shade400;
    if (percent < 0.85) return Colors.blue.shade400;
    return Colors.green.shade500;
  }

  String _progressLabel(double percent) {
    if (percent == 0) return 'Not started yet — let\'s go! 🚀';
    if (percent < 0.3) return 'Just getting started — keep going!';
    if (percent < 0.6) return 'Good progress — stay consistent!';
    if (percent < 0.85) return 'Great work — almost there!';
    if (percent < 1.0) return 'Excellent — finishing the last ones!';
    return 'All cards started! 🎉';
  }

  Widget _buildLevelDistribution(BuildContext context, _StatsData data) {
    final maxCount = data.levelMap.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: data.sortedLevels.map((level) {
          final count = data.levelMap[level]!;
          final ratio = count / maxCount;
          final barColor = level == 0 ? Colors.grey.shade400 : Colors.blue.shade400;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    level == 0 ? 'New' : 'Lvl $level',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: 20,
                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, _StatsData data) {
    final lastModifiedLabel = _relativeDate(data.lastModified);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildActivityRow(
            context,
            icon: Icons.access_time_outlined,
            color: Colors.purple,
            label: 'Last activity',
            value: lastModifiedLabel,
          ),
          const Divider(height: 20),
          _buildActivityRow(
            context,
            icon: Icons.today_outlined,
            color: Colors.teal,
            label: 'Reviewed today',
            value: '${data.reviewedToday} card${data.reviewedToday == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _relativeDate(dynamic modified) {
    final now = DateTimeUtil.now();
    final diff = now.difference(modified as DateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _StatsData {
  final int total;
  final int started;
  final int totalReviews;
  final int maxLevel;
  final Map<int, int> levelMap;
  final List<int> sortedLevels;
  final int reviewedToday;
  final dynamic lastModified;

  const _StatsData({
    required this.total,
    required this.started,
    required this.totalReviews,
    required this.maxLevel,
    required this.levelMap,
    required this.sortedLevels,
    required this.reviewedToday,
    required this.lastModified,
  });

  factory _StatsData.empty() => const _StatsData(
        total: 0,
        started: 0,
        totalReviews: 0,
        maxLevel: 0,
        levelMap: {},
        sortedLevels: [],
        reviewedToday: 0,
        lastModified: null,
      );
}
