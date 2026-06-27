import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/entity/deck_entity.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/repository/card_repository.dart';
import 'package:leitner_cards/repository/deck_repository.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/service/study_log_service.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../util/color_util.dart';

/// Learning-progress statistics screen, one tab per user deck.
///
/// Stats are computed synchronously from the Hive boxes on each build — no
/// separate state is needed since the data is already in-memory.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final decks = Get.find<DeckRepository>().findAll();

    if (decks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistics')),
        body: const Center(
          child: Text('No decks yet — create one first.'),
        ),
      );
    }

    return DefaultTabController(
      length: decks.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistics'),
          bottom: TabBar(
            isScrollable: decks.length > 3,
            tabs: decks.map((d) => Tab(text: d.name)).toList(),
          ),
        ),
        body: TabBarView(
          children: decks.map((d) => _StatsTab(deck: d)).toList(),
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final DeckEntity deck;

  const _StatsTab({required this.deck});

  /// Bridge to legacy GroupCode for study log queries.
  GroupCode? get _legacyGroupCode =>
      deck.groupCode.isNotEmpty ? GroupCode.fromCode(deck.groupCode) : null;

  _StatsData _compute() {
    final cardRepo = Get.find<CardRepository>();
    final progressRepo = Get.find<ProgressRepository>();

    // Legacy decks use groupCode, future decks will use deckId.
    final cards = deck.groupCode.isNotEmpty
        ? cardRepo.findAllByGroupCode(GroupCode.fromCode(deck.groupCode))
        : <CardEntity>[];

    if (cards.isEmpty) return _StatsData.empty();

    final progressList =
        cards.map((c) => progressRepo.findOrCreate(c.id)).toList();

    final total = cards.length;
    final started = progressList.where((p) => p.level > 0).length;
    final totalReviews = progressList.fold<int>(0, (sum, p) => sum + p.order);
    final maxLevel =
        progressList.map((p) => p.level).reduce((a, b) => a > b ? a : b);

    // Level distribution (sorted ascending)
    final levelMap = <int, int>{};
    for (final p in progressList) {
      levelMap[p.level] = (levelMap[p.level] ?? 0) + 1;
    }
    final sortedLevels = levelMap.keys.toList()..sort();

    // Recent activity
    final now = DateTimeUtil.now();
    final today = progressList.where((p) {
      return p.modified.year == now.year &&
          p.modified.month == now.month &&
          p.modified.day == now.day;
    }).length;

    final lastModified = progressList
        .map((p) => p.modified)
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
            Icon(Icons.inbox_outlined,
                size: 56, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No cards yet for ${deck.name}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15),
            ),
          ],
        ),
      );
    }

    final progressPercent = data.started / data.total;
    final studyLog = Get.find<StudyLogService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 7-day bar chart
          _buildPeriodBreakdown(context, studyLog),

          const SizedBox(height: 12),

          // Week / Month / Year summary tiles
          _buildPeriodTiles(context, studyLog),

          const SizedBox(height: 24),

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
          _buildProgressCard(
              context, progressPercent, data.started, data.total),

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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Three gradient tiles: This Week / This Month / This Year.
  Widget _buildPeriodTiles(BuildContext context, StudyLogService log) {
    final accent = Color(deck.colorValue);
    final gc = _legacyGroupCode;
    final periods = [
      (
        label: 'Week',
        secs: gc != null ? log.periodSecs(gc, days: 7) : 0,
        icon: Icons.view_week_outlined,
        gradient: [
          accent.withValues(alpha: 0.85),
          accent.withValues(alpha: 0.55)
        ]
      ),
      (
        label: 'Month',
        secs: gc != null ? log.periodSecs(gc, days: 30) : 0,
        icon: Icons.calendar_month_outlined,
        gradient: [
          accent.withValues(alpha: 0.65),
          accent.withValues(alpha: 0.35)
        ]
      ),
      (
        label: 'Year',
        secs: gc != null ? log.periodSecs(gc, days: 365) : 0,
        icon: Icons.auto_stories_outlined,
        gradient: [
          accent.withValues(alpha: 0.50),
          accent.withValues(alpha: 0.25)
        ]
      ),
    ];

    return Row(
      children: periods.map((p) {
        final h = p.secs ~/ 3600;
        final m = (p.secs % 3600) ~/ 60;
        final s = p.secs % 60;
        final valueText = p.secs == 0
            ? '—'
            : h > 0
                ? '${h}h ${m}m'
                : m > 0
                    ? '${m}m ${s}s'
                    : '${s}s';

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: p.label != 'Year' ? 8 : 0,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: p.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(p.icon, size: 18, color: Colors.white70),
                const SizedBox(height: 8),
                Text(
                  valueText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  p.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 7-day bar chart: today on the right, each bar = study seconds that day.
  /// Bar heights are proportional to the day with the most study time.
  Widget _buildPeriodBreakdown(BuildContext context, StudyLogService log) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTimeUtil.now();

    // Build list of last 7 days oldest→newest (index 6 = today).
    final days = List.generate(7, (i) {
      final dt = now.subtract(Duration(days: 6 - i));
      final key = log.dateKey(dt);
      final gc = _legacyGroupCode;
      final secs = gc != null ? log.daySecs(gc, key) : 0;
      final label = _dayLabel(dt.weekday, i == 6);
      return (key: key, secs: secs, label: label, isToday: i == 6);
    });

    final maxSecs = days.map((d) => d.secs).fold(0, (a, b) => a > b ? a : b);
    final accentColor = Color(deck.colorValue);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST 7 DAYS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                final ratio = maxSecs == 0 ? 0.0 : d.secs / maxSecs;
                final barColor = d.isToday
                    ? accentColor
                    : accentColor.withValues(alpha: 0.45);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Time label above bar (only if non-zero)
                        if (d.secs > 0)
                          Text(
                            _shortTime(d.secs),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 3),
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: ratio == 0 ? 3 : (ratio * 80).clamp(3, 80),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Day label
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                d.isToday ? FontWeight.w700 : FontWeight.w400,
                            color: d.isToday
                                ? accentColor
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Short day label: Mon–Sun, today → "Today".
  String _dayLabel(int weekday, bool isToday) {
    if (isToday) return 'Today';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  /// Very compact time: "2h", "45m", "30s".
  String _shortTime(int secs) {
    if (secs >= 3600) return '${secs ~/ 3600}h';
    if (secs >= 60) return '${secs ~/ 60}m';
    return '${secs}s';
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
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
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
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_progressColor(percent)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _progressLabel(percent),
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  Color _levelColor(int level, BuildContext context) =>
      ColorUtil.levelColor(level, Theme.of(context).brightness);

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
          final barColor = _levelColor(level, context);

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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
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
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
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
            value:
                '${data.reviewedToday} card${data.reviewedToday == 1 ? '' : 's'}',
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
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
