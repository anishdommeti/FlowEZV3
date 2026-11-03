import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/dimensions.dart';
import '../../models/queue_model.dart';
import '../admin/widgets/analytics_card.dart';
import '../admin/widgets/bar_chart_widget.dart';
import '../admin/widgets/line_chart_widget.dart';
import '../admin/widgets/pie_chart_widget.dart';

double _safeNumericValue(Object? value, {double fallback = 0.0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is bool) {
    return value ? 1.0 : 0.0;
  }
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _AnalyticsFilter _filter = _AnalyticsFilter.week;
  final Set<_AnalyticsSection> _expandedSections = {
    _AnalyticsSection.quickStats,
    _AnalyticsSection.smartInsights,
  };
  final ScrollController _scrollController = ScrollController();
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTimeRange _resolveDateRange() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return switch (_filter) {
      _AnalyticsFilter.today => DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: end,
      ),
      _AnalyticsFilter.week => DateTimeRange(
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6)),
        end: end,
      ),
      _AnalyticsFilter.month => DateTimeRange(
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29)),
        end: end,
      ),
    };
  }

  void _showExportDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(content)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _exportAnalytics(_AnalyticsData analytics) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.pagePadding,
              8,
              AppDimensions.pagePadding,
              AppDimensions.pagePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Export', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppDimensions.sectionSpacing),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showExportDialog('CSV Report', analytics.toCsv());
                  },
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('CSV Preview'),
                ),
                const SizedBox(height: AppDimensions.cardSpacing),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showExportDialog(
                      'PDF Report Preview',
                      analytics.toPdfSummary(),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF Preview'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setSectionExpanded(_AnalyticsSection section, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedSections.add(section);
      } else {
        _expandedSections.remove(section);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _resolveDateRange();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('queues').snapshots(),
          builder: (context, queuesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('tokens')
                  .snapshots(),
              builder: (context, tokensSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('history')
                      .snapshots(),
                  builder: (context, historySnapshot) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder: (context, usersSnapshot) {
                        if (queuesSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            tokensSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            historySnapshot.connectionState ==
                                ConnectionState.waiting ||
                            usersSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final errors = [
                          queuesSnapshot.error,
                          tokensSnapshot.error,
                          historySnapshot.error,
                          usersSnapshot.error,
                        ].whereType<Object>().toList();

                        if (errors.isNotEmpty) {
                          return _AnalyticsMessage(
                            icon: Icons.error_outline,
                            title: 'Unable to load analytics',
                            message: errors.first.toString(),
                          );
                        }

                        final queues =
                            queuesSnapshot.data?.docs
                                .map((doc) => QueueModel.fromMap(doc.data()))
                                .toList() ??
                            const <QueueModel>[];
                        final tokenDocs = tokensSnapshot.data?.docs ?? const [];
                        final historyDocs =
                            historySnapshot.data?.docs ?? const [];
                        final userDocs = usersSnapshot.data?.docs ?? const [];

                        final analytics = _buildAnalytics(
                          queues: queues,
                          tokenDocs: tokenDocs,
                          historyDocs: historyDocs,
                          userDocs: userDocs,
                          range: range,
                        );

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 1100;
                            final medium = constraints.maxWidth >= 720;
                            final statsColumns = wide ? 4 : (medium ? 2 : 1);
                            final compactColumns = wide ? 3 : (medium ? 2 : 1);

                            return PageStorage(
                              bucket: _pageStorageBucket,
                              child: ListView(
                                key: const PageStorageKey<String>(
                                  'analytics-scroll',
                                ),
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  AppDimensions.pagePadding,
                                  AppDimensions.pagePadding,
                                  AppDimensions.pagePadding,
                                  AppDimensions.pagePadding + 4,
                                ),
                                children: [
                                  _AnalyticsHeader(
                                    filter: _filter,
                                    rangeLabel: _filterLabel(_filter),
                                    onFilterChanged: (filter) {
                                      setState(() {
                                        _filter = filter;
                                      });
                                    },
                                    onRefresh: () => setState(() {}),
                                    onExport: () => _exportAnalytics(analytics),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Quick Stats',
                                    subtitle:
                                        '${analytics.totalQueues} queues, ${analytics.waitingUsers} waiting, ${analytics.completedTokens} completed',
                                    icon: Icons.dashboard_outlined,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.quickStats,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.quickStats,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-quick-stats',
                                    ),
                                    childBuilder: (_) => _StatsGrid(
                                      crossAxisCount: statsColumns,
                                      children: [
                                        AnalyticsCard(
                                          title: 'Total Queues',
                                          value: analytics.totalQueues
                                              .toString(),
                                          icon: Icons.view_list_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Active Queues',
                                          value: analytics.activeQueues
                                              .toString(),
                                          icon: Icons.lock_open_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Closed Queues',
                                          value: analytics.closedQueues
                                              .toString(),
                                          icon: Icons.lock_outline_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Total Users',
                                          value: analytics.totalUsers
                                              .toString(),
                                          icon: Icons.people_alt_outlined,
                                        ),
                                        AnalyticsCard(
                                          title: 'Waiting Users',
                                          value: analytics.waitingUsers
                                              .toString(),
                                          icon: Icons.hourglass_bottom_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Completed Tokens',
                                          value: analytics.completedTokens
                                              .toString(),
                                          icon: Icons.task_alt_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Cancelled Tokens',
                                          value: analytics.cancelledTokens
                                              .toString(),
                                          icon: Icons.cancel_outlined,
                                        ),
                                        AnalyticsCard(
                                          title: 'Average Wait Time',
                                          value:
                                              '${analytics.averageWaitTimeMinutes} mins',
                                          icon: Icons.schedule_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Queue Trend',
                                    subtitle:
                                        '${analytics.averageTokensPerDay} average tokens per day across the selected range',
                                    icon: Icons.show_chart_rounded,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.queueTrend,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.queueTrend,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-queue-trend',
                                    ),
                                    childBuilder: (_) => LineChartWidget(
                                      title: 'Daily Queue Activity',
                                      dataPoints: analytics.dailyActivityValues,
                                      labels: analytics.dailyActivityLabels,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing * 0.6,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Queue Distribution',
                                    subtitle:
                                        'Status mix and user load by queue for the current dataset',
                                    icon: Icons.pie_chart_outline_rounded,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.queueDistribution,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.queueDistribution,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-queue-distribution',
                                    ),
                                    childBuilder: (_) => medium
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: PieChartWidget(
                                                  title:
                                                      'Token Status Distribution',
                                                  sections: analytics
                                                      .pieSections(context),
                                                ),
                                              ),
                                              const SizedBox(
                                                width:
                                                    AppDimensions.cardSpacing,
                                              ),
                                              Expanded(
                                                child: BarChartWidget(
                                                  title: 'Users Per Queue',
                                                  values: analytics
                                                      .usersPerQueueValues,
                                                  labels: analytics
                                                      .usersPerQueueLabels,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              PieChartWidget(
                                                title:
                                                    'Token Status Distribution',
                                                sections: analytics.pieSections(
                                                  context,
                                                ),
                                              ),
                                              const SizedBox(
                                                height:
                                                    AppDimensions.cardSpacing,
                                              ),
                                              BarChartWidget(
                                                title: 'Users Per Queue',
                                                values: analytics
                                                    .usersPerQueueValues,
                                                labels: analytics
                                                    .usersPerQueueLabels,
                                              ),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Peak Hours',
                                    subtitle:
                                        'Busiest hour is ${analytics.peakHourLabel}',
                                    icon: Icons.access_time_filled_rounded,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.peakHours,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.peakHours,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-peak-hours',
                                    ),
                                    childBuilder: (_) => _StatsGrid(
                                      crossAxisCount: compactColumns,
                                      children: [
                                        AnalyticsCard(
                                          title: 'Peak Hour',
                                          value: analytics.peakHourLabel,
                                          icon:
                                              Icons.access_time_filled_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Average Wait Time',
                                          value:
                                              '${analytics.averageWaitTimeMinutes} mins',
                                          icon: Icons.schedule_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Average Tokens/Day',
                                          value: analytics.averageTokensPerDay
                                              .toString(),
                                          icon: Icons.bar_chart_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Top Queues',
                                    subtitle: analytics.topQueues.isEmpty
                                        ? 'No queue activity yet'
                                        : '${analytics.topQueues.first.name} leads current activity',
                                    icon: Icons.emoji_events_outlined,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.topQueues,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.topQueues,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-top-queues',
                                    ),
                                    childBuilder: (_) => _InsightList(
                                      items: analytics.topQueues
                                          .map(
                                            (entry) => _InsightItemData(
                                              title: entry.name,
                                              value:
                                                  '${entry.value} users joined',
                                              icon: Icons.trending_up_rounded,
                                              subtitle:
                                                  'Queue load in the current dataset',
                                            ),
                                          )
                                          .toList(),
                                      emptyMessage:
                                          'No queue usage data is available yet.',
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Problem Queues',
                                    subtitle: analytics.problemQueues.isEmpty
                                        ? 'No problem queues detected'
                                        : '${analytics.problemQueues.length} queues need attention',
                                    icon: Icons.warning_amber_rounded,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.problemQueues,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.problemQueues,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-problem-queues',
                                    ),
                                    childBuilder: (_) => _InsightList(
                                      items: analytics.problemQueues
                                          .map(
                                            (entry) => _InsightItemData(
                                              title: entry.name,
                                              value:
                                                  '${entry.value} people still in line',
                                              icon: Icons.error_outline_rounded,
                                              subtitle:
                                                  'Current queue length is above the average',
                                            ),
                                          )
                                          .toList(),
                                      emptyMessage:
                                          'Every queue is within the current average range.',
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing * 0.6,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'User Insights',
                                    subtitle:
                                        '${analytics.dailyUsers} daily, ${analytics.weeklyUsers} weekly, ${analytics.monthlyUsers} monthly active users',
                                    icon: Icons.people_outline_rounded,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.userInsights,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.userInsights,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-user-insights',
                                    ),
                                    childBuilder: (_) => _StatsGrid(
                                      crossAxisCount: compactColumns,
                                      children: [
                                        AnalyticsCard(
                                          title: 'Daily Users',
                                          value: analytics.dailyUsers
                                              .toString(),
                                          icon: Icons.today_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Weekly Users',
                                          value: analytics.weeklyUsers
                                              .toString(),
                                          icon: Icons.date_range_rounded,
                                        ),
                                        AnalyticsCard(
                                          title: 'Monthly Users',
                                          value: analytics.monthlyUsers
                                              .toString(),
                                          icon: Icons.calendar_month_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing * 0.6,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Recent Activity',
                                    subtitle: analytics.recentActivity.isEmpty
                                        ? 'No recent activity captured'
                                        : '${analytics.recentActivity.length} recent events',
                                    icon: Icons.history_rounded,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.recentActivity,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.recentActivity,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-recent-activity',
                                    ),
                                    childBuilder: (_) => _InsightList(
                                      items: analytics.recentActivity
                                          .map(
                                            (entry) => _InsightItemData(
                                              title: entry.title,
                                              value: entry.value,
                                              icon: entry.icon,
                                              subtitle: entry.subtitle,
                                            ),
                                          )
                                          .toList(),
                                      emptyMessage:
                                          'Recent joined and completed events will appear here.',
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing * 0.6,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Smart Insights',
                                    subtitle: analytics.smartInsights.isEmpty
                                        ? 'No smart insights yet'
                                        : analytics.smartInsights.first.value,
                                    icon: Icons.auto_awesome_outlined,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.smartInsights,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.smartInsights,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-smart-insights',
                                    ),
                                    childBuilder: (_) => _InsightList(
                                      items: analytics.smartInsights
                                          .map(
                                            (entry) => _InsightItemData(
                                              title: entry.title,
                                              value: entry.value,
                                              icon: entry.icon,
                                              subtitle: entry.subtitle,
                                            ),
                                          )
                                          .toList(),
                                      emptyMessage:
                                          'Insights will appear once enough activity has been recorded.',
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.cardSpacing * 0.6,
                                  ),
                                  _AnalyticsSectionCard(
                                    title: 'Reports',
                                    subtitle:
                                        'Preview export payloads without changing current analytics logic',
                                    icon: Icons.description_outlined,
                                    isExpanded: _expandedSections.contains(
                                      _AnalyticsSection.reports,
                                    ),
                                    onExpansionChanged: (expanded) =>
                                        _setSectionExpanded(
                                          _AnalyticsSection.reports,
                                          expanded,
                                        ),
                                    sectionKey: const PageStorageKey<String>(
                                      'analytics-reports',
                                    ),
                                    childBuilder: (_) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () => _showExportDialog(
                                            'CSV Report',
                                            analytics.toCsv(),
                                          ),
                                          icon: const Icon(
                                            Icons.table_chart_outlined,
                                          ),
                                          label: const Text('Open CSV Preview'),
                                        ),
                                        const SizedBox(
                                          height:
                                              AppDimensions.cardSpacing * 0.6,
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _showExportDialog(
                                            'PDF Report Preview',
                                            analytics.toPdfSummary(),
                                          ),
                                          icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                          ),
                                          label: const Text('Open PDF Preview'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  _AnalyticsData _buildAnalytics({
    required List<QueueModel> queues,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> tokenDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> historyDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    required DateTimeRange range,
  }) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(const Duration(days: 6));
    final startOfMonth = startOfToday.subtract(const Duration(days: 29));

    final filteredTokenDocs = tokenDocs.where((doc) {
      final joinedAt = _parseDateTime(doc.data()['joinedAt']);
      return !joinedAt.isBefore(range.start) && !joinedAt.isAfter(range.end);
    }).toList();

    final filteredHistoryDocs = historyDocs.where((doc) {
      final completedAt = _parseDateTime(doc.data()['completedAt']);
      return !completedAt.isBefore(range.start) &&
          !completedAt.isAfter(range.end);
    }).toList();

    final totalQueues = queues.length;
    final activeQueues = queues
        .where((queue) => _isQueueOpen(queue.status))
        .length;
    final closedQueues = totalQueues - activeQueues;
    final totalUsers = userDocs.length;
    final waitingUsers = tokenDocs
        .where((doc) => (doc.data()['status'] as String? ?? '') == 'waiting')
        .length;
    final completedTokens = filteredHistoryDocs.length;
    final cancelledTokens = filteredTokenDocs
        .where((doc) => (doc.data()['status'] as String? ?? '') == 'cancelled')
        .length;

    final allEventTimes = [
      ...filteredTokenDocs.map((doc) => _parseDateTime(doc.data()['joinedAt'])),
      ...filteredHistoryDocs.map(
        (doc) => _parseDateTime(doc.data()['completedAt']),
      ),
    ];
    final peakHour = _peakHour(allEventTimes);

    final dailyUsers = _uniqueUsersSince(tokenDocs, startOfToday);
    final weeklyUsers = _uniqueUsersSince(tokenDocs, startOfWeek);
    final monthlyUsers = _uniqueUsersSince(tokenDocs, startOfMonth);

    final dailyBuckets = List.generate(
      7,
      (index) => startOfToday.subtract(Duration(days: 6 - index)),
    );
    final dailyActivityValues = dailyBuckets.map((bucketStart) {
      final bucketEnd = bucketStart.add(const Duration(days: 1));
      final joinedCount = tokenDocs.where((doc) {
        final joinedAt = _parseDateTime(doc.data()['joinedAt']);
        return !joinedAt.isBefore(bucketStart) && joinedAt.isBefore(bucketEnd);
      }).length;
      return _safeNumericValue(joinedCount);
    }).toList();
    final dailyActivityLabels = dailyBuckets
        .map((date) => _weekdayLabel(date.weekday))
        .toList();

    final usersPerQueue = <String, int>{};
    for (final doc in tokenDocs) {
      final queueId = doc.data()['queueId'] as String? ?? '';
      usersPerQueue.update(queueId, (value) => value + 1, ifAbsent: () => 1);
    }

    final queueLengths = <String, int>{
      for (final queue in queues)
        queue.queueId: (queue.lastToken - queue.currentToken).clamp(0, 1 << 31),
    };
    final queueNameById = {
      for (final queue in queues) queue.queueId: queue.name,
    };

    final queueEntries = usersPerQueue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topQueueEntries = queueEntries.take(6).toList();
    final usersPerQueueValues = topQueueEntries
        .map((entry) => _safeNumericValue(entry.value))
        .toList();
    final usersPerQueueLabels = topQueueEntries
        .map((entry) => _shortLabel(queueNameById[entry.key] ?? entry.key))
        .toList();

    final completedByQueue = <String, int>{};
    for (final doc in historyDocs) {
      final queueId = doc.data()['queueId'] as String? ?? '';
      completedByQueue.update(queueId, (value) => value + 1, ifAbsent: () => 1);
    }

    final fastestQueue = _findQueueByMetric(
      queues: queues,
      completedByQueue: completedByQueue,
      preferHigher: true,
    );
    final slowestQueue = _findQueueByMetric(
      queues: queues,
      completedByQueue: completedByQueue,
      preferHigher: false,
    );

    final averageQueueLength = queues.isEmpty
        ? 0.0
        : queues
                  .map(
                    (queue) => (queue.lastToken - queue.currentToken).clamp(
                      0,
                      1 << 31,
                    ),
                  )
                  .reduce((a, b) => a + b) /
              queues.length;
    final averageWaitTimeMinutes = averageQueueLength == 0
        ? 0
        : (averageQueueLength * 2).round();
    final averageProcessingTimeMinutes = completedTokens == 0 ? 0 : 2;
    final queueUtilization = totalQueues == 0
        ? 0
        : ((activeQueues / totalQueues) * 100).round();
    final averageTokensPerDay = dailyActivityValues.isEmpty
        ? 0
        : (dailyActivityValues.reduce((a, b) => a + b) /
                  dailyActivityValues.length)
              .round();

    final topQueues = topQueueEntries
        .map(
          (entry) => _QueueMetric(
            name: queueNameById[entry.key] ?? entry.key,
            value: entry.value,
          ),
        )
        .toList();

    final problemQueues =
        queueLengths.entries
            .where((entry) => entry.value > averageQueueLength.round())
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final recentActivity = <_ActivityItem>[
      ...filteredTokenDocs.map((doc) {
        final data = doc.data();
        final queueName =
            queueNameById[data['queueId'] as String? ?? ''] ?? 'Unknown queue';
        final joinedAt = _parseDateTime(data['joinedAt']);
        final tokenNumber = (data['tokenNumber'] as num?)?.toInt();
        return _ActivityItem(
          title: '$queueName joined',
          value: 'Token ${tokenNumber ?? '-'} at ${_formatDateTime(joinedAt)}',
          subtitle: 'Recent queue join event',
          icon: Icons.login_rounded,
          occurredAt: joinedAt,
        );
      }),
      ...filteredHistoryDocs.map((doc) {
        final data = doc.data();
        final queueName =
            queueNameById[data['queueId'] as String? ?? ''] ?? 'Unknown queue';
        final completedAt = _parseDateTime(data['completedAt']);
        final tokenNumber = (data['tokenNumber'] as num?)?.toInt();
        return _ActivityItem(
          title: '$queueName completed',
          value:
              'Token ${tokenNumber ?? '-'} at ${_formatDateTime(completedAt)}',
          subtitle: 'Recent completion event',
          icon: Icons.task_alt_rounded,
          occurredAt: completedAt,
        );
      }),
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final smartInsights = <_ActivityItem>[
      _ActivityItem(
        title: 'Throughput',
        value: completedTokens == 0
            ? 'No completed tokens in the selected range yet.'
            : '$completedTokens tokens were completed in this ${_filterLabel(_filter).toLowerCase()} window.',
        subtitle: 'Based on history documents in the current filter',
        icon: Icons.task_alt_rounded,
        occurredAt: now,
      ),
      _ActivityItem(
        title: 'Demand pattern',
        value: topQueues.isEmpty
            ? 'Queue demand has not formed a clear leader yet.'
            : '${topQueues.first.name} is currently drawing the most users.',
        subtitle: 'Calculated from token joins per queue',
        icon: Icons.trending_up_rounded,
        occurredAt: now,
      ),
      _ActivityItem(
        title: 'Operational pressure',
        value: problemQueues.isEmpty
            ? 'Queue load looks balanced right now.'
            : '${problemQueues.first.value} users are still pending in ${queueNameById[problemQueues.first.key] ?? problemQueues.first.key}.',
        subtitle: 'Compared against average queue length',
        icon: Icons.warning_amber_rounded,
        occurredAt: now,
      ),
      _ActivityItem(
        title: 'Coverage',
        value: '$queueUtilization% of queues are open right now.',
        subtitle: 'Active queue ratio from the current snapshot',
        icon: Icons.insights_rounded,
        occurredAt: now,
      ),
    ];

    return _AnalyticsData(
      totalQueues: totalQueues,
      activeQueues: activeQueues,
      closedQueues: closedQueues,
      totalUsers: totalUsers,
      waitingUsers: waitingUsers,
      completedTokens: completedTokens,
      cancelledTokens: cancelledTokens,
      averageWaitTimeMinutes: averageWaitTimeMinutes,
      peakHourLabel: peakHour,
      dailyUsers: dailyUsers,
      weeklyUsers: weeklyUsers,
      monthlyUsers: monthlyUsers,
      dailyActivityValues: dailyActivityValues,
      dailyActivityLabels: dailyActivityLabels,
      usersPerQueueValues: usersPerQueueValues,
      usersPerQueueLabels: usersPerQueueLabels,
      fastestQueue: fastestQueue,
      slowestQueue: slowestQueue,
      averageProcessingTimeMinutes: averageProcessingTimeMinutes,
      averageQueueLength: averageQueueLength.round(),
      queueUtilization: queueUtilization,
      averageTokensPerDay: averageTokensPerDay,
      topQueues: topQueues,
      problemQueues: problemQueues
          .take(6)
          .map(
            (entry) => _QueueMetric(
              name: queueNameById[entry.key] ?? entry.key,
              value: entry.value,
            ),
          )
          .toList(),
      recentActivity: recentActivity.take(8).toList(),
      smartInsights: smartInsights,
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({
    required this.filter,
    required this.rangeLabel,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onExport,
  });

  final _AnalyticsFilter filter;
  final String rangeLabel;
  final ValueChanged<_AnalyticsFilter> onFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analytics', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppDimensions.cardSpacing * 0.3),
                      Text(
                        'Time filter: $rangeLabel',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  onPressed: onExport,
                  tooltip: 'Export',
                  icon: const Icon(Icons.download_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.cardSpacing * 0.8),
            SegmentedButton<_AnalyticsFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<_AnalyticsFilter>(
                  value: _AnalyticsFilter.today,
                  label: Text('Today'),
                ),
                ButtonSegment<_AnalyticsFilter>(
                  value: _AnalyticsFilter.week,
                  label: Text('Week'),
                ),
                ButtonSegment<_AnalyticsFilter>(
                  value: _AnalyticsFilter.month,
                  label: Text('Month'),
                ),
              ],
              selected: {_filterFromValue(filter)},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  onFilterChanged(selection.first);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  _AnalyticsFilter _filterFromValue(_AnalyticsFilter value) => value;
}

class _AnalyticsSectionCard extends StatelessWidget {
  const _AnalyticsSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.sectionKey,
    required this.childBuilder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Key sectionKey;
  final WidgetBuilder childBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: sectionKey,
        initiallyExpanded: isExpanded,
        maintainState: true,
        onExpansionChanged: onExpansionChanged,
        leading: Icon(icon, color: theme.colorScheme.primary),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.cardSpacing * 0.8,
          vertical: AppDimensions.cardSpacing * 0.3,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppDimensions.cardSpacing * 0.8,
          0,
          AppDimensions.cardSpacing * 0.8,
          AppDimensions.cardSpacing * 0.8,
        ),
        title: Text(title, softWrap: true, maxLines: 2),
        subtitle: Text(subtitle, softWrap: true, maxLines: 2),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: isExpanded ? [Builder(builder: childBuilder)] : const [],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.crossAxisCount, required this.children});

  final int crossAxisCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppDimensions.cardSpacing,
        mainAxisSpacing: AppDimensions.cardSpacing,
        mainAxisExtent: 110,
      ),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class _InsightList extends StatelessWidget {
  const _InsightList({required this.items, required this.emptyMessage});

  final List<_InsightItemData> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          emptyMessage,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _InsightTile(item: items[index]),
          if (index < items.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.item});

  final _InsightItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.icon,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppDimensions.cardSpacing * 0.6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: theme.textTheme.titleMedium,
                softWrap: true,
                maxLines: 2,
              ),
              const SizedBox(height: AppDimensions.cardSpacing * 0.2),
              Text(
                item.value,
                style: theme.textTheme.bodyLarge,
                softWrap: true,
                maxLines: 2,
              ),
              if (item.subtitle != null) ...[
                const SizedBox(height: AppDimensions.cardSpacing * 0.2),
                Text(
                  item.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  softWrap: true,
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsMessage extends StatelessWidget {
  const _AnalyticsMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding * 1.2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding * 1.2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: AppDimensions.cardSpacing * 0.8),
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppDimensions.cardSpacing * 0.4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AnalyticsFilter { today, week, month }

enum _AnalyticsSection {
  quickStats,
  queueTrend,
  queueDistribution,
  peakHours,
  topQueues,
  problemQueues,
  userInsights,
  recentActivity,
  smartInsights,
  reports,
}

class _AnalyticsData {
  const _AnalyticsData({
    required this.totalQueues,
    required this.activeQueues,
    required this.closedQueues,
    required this.totalUsers,
    required this.waitingUsers,
    required this.completedTokens,
    required this.cancelledTokens,
    required this.averageWaitTimeMinutes,
    required this.peakHourLabel,
    required this.dailyUsers,
    required this.weeklyUsers,
    required this.monthlyUsers,
    required this.dailyActivityValues,
    required this.dailyActivityLabels,
    required this.usersPerQueueValues,
    required this.usersPerQueueLabels,
    required this.fastestQueue,
    required this.slowestQueue,
    required this.averageProcessingTimeMinutes,
    required this.averageQueueLength,
    required this.queueUtilization,
    required this.averageTokensPerDay,
    required this.topQueues,
    required this.problemQueues,
    required this.recentActivity,
    required this.smartInsights,
  });

  final int totalQueues;
  final int activeQueues;
  final int closedQueues;
  final int totalUsers;
  final int waitingUsers;
  final int completedTokens;
  final int cancelledTokens;
  final int averageWaitTimeMinutes;
  final String peakHourLabel;
  final int dailyUsers;
  final int weeklyUsers;
  final int monthlyUsers;
  final List<double> dailyActivityValues;
  final List<String> dailyActivityLabels;
  final List<double> usersPerQueueValues;
  final List<String> usersPerQueueLabels;
  final String fastestQueue;
  final String slowestQueue;
  final int averageProcessingTimeMinutes;
  final int averageQueueLength;
  final int queueUtilization;
  final int averageTokensPerDay;
  final List<_QueueMetric> topQueues;
  final List<_QueueMetric> problemQueues;
  final List<_ActivityItem> recentActivity;
  final List<_ActivityItem> smartInsights;

  List<PieChartSectionData> pieSections(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      ('Completed', _safeNumericValue(completedTokens), Colors.green),
      ('Waiting', _safeNumericValue(waitingUsers), theme.colorScheme.primary),
      (
        'Cancelled',
        _safeNumericValue(cancelledTokens),
        theme.colorScheme.error,
      ),
    ].where((entry) => entry.$2 > 0).toList();

    return values
        .map(
          (entry) => PieChartSectionData(
            value: entry.$2,
            color: entry.$3,
            radius: 58,
            title: '${entry.$1}\n${entry.$2.toInt()}',
            titleStyle: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        )
        .toList();
  }

  String toCsv() {
    final buffer = StringBuffer()
      ..writeln('Metric,Value')
      ..writeln('Total Queues,$totalQueues')
      ..writeln('Active Queues,$activeQueues')
      ..writeln('Closed Queues,$closedQueues')
      ..writeln('Total Users,$totalUsers')
      ..writeln('Waiting Users,$waitingUsers')
      ..writeln('Completed Tokens,$completedTokens')
      ..writeln('Cancelled Tokens,$cancelledTokens')
      ..writeln('Average Wait Time,$averageWaitTimeMinutes mins')
      ..writeln('Peak Hour,$peakHourLabel')
      ..writeln('Daily Users,$dailyUsers')
      ..writeln('Weekly Users,$weeklyUsers')
      ..writeln('Monthly Users,$monthlyUsers')
      ..writeln('Fastest Queue,$fastestQueue')
      ..writeln('Slowest Queue,$slowestQueue')
      ..writeln('Average Processing Time,$averageProcessingTimeMinutes mins')
      ..writeln('Average Queue Length,$averageQueueLength')
      ..writeln('Queue Utilization,$queueUtilization%')
      ..writeln('Average Tokens per Day,$averageTokensPerDay');
    return buffer.toString();
  }

  String toPdfSummary() {
    return '${const JsonEncoder.withIndent('  ').convert({'reportType': 'FlowEZ Analytics Summary', 'note': 'PDF generation package is not installed; this is a printable summary payload.'})}\n\n${toCsv()}';
  }
}

class _QueueMetric {
  const _QueueMetric({required this.name, required this.value});

  final String name;
  final int value;
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.occurredAt,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final DateTime occurredAt;
}

class _InsightItemData {
  const _InsightItemData({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
}

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

bool _isQueueOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}

int _uniqueUsersSince(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> tokenDocs,
  DateTime start,
) {
  final userIds = <String>{};
  for (final doc in tokenDocs) {
    final joinedAt = _parseDateTime(doc.data()['joinedAt']);
    if (!joinedAt.isBefore(start)) {
      final userId = doc.data()['userId'] as String? ?? '';
      if (userId.isNotEmpty) {
        userIds.add(userId);
      }
    }
  }
  return userIds.length;
}

String _peakHour(List<DateTime> dates) {
  if (dates.isEmpty) {
    return '-';
  }
  final counts = <int, int>{};
  for (final date in dates) {
    counts.update(date.hour, (value) => value + 1, ifAbsent: () => 1);
  }
  final peak = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final hour = peak.toString().padLeft(2, '0');
  return '$hour:00';
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    default:
      return 'Sun';
  }
}

String _shortLabel(String value) {
  return value.length <= 8 ? value : '${value.substring(0, 8)}...';
}

String _filterLabel(_AnalyticsFilter filter) {
  switch (filter) {
    case _AnalyticsFilter.today:
      return 'Today';
    case _AnalyticsFilter.week:
      return 'Week';
    case _AnalyticsFilter.month:
      return 'Month';
  }
}

String _findQueueByMetric({
  required List<QueueModel> queues,
  required Map<String, int> completedByQueue,
  required bool preferHigher,
}) {
  if (queues.isEmpty || completedByQueue.isEmpty) {
    return '-';
  }

  final entries = completedByQueue.entries.toList()
    ..sort(
      (a, b) => preferHigher
          ? b.value.compareTo(a.value)
          : a.value.compareTo(b.value),
    );
  final queueId = entries.first.key;
  return queues
      .firstWhere(
        (queue) => queue.queueId == queueId,
        orElse: () => QueueModel(
          queueId: '',
          name: '-',
          description: '',
          status: 'closed',
          currentToken: 0,
          lastToken: 0,
          createdBy: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      )
      .name;
}

String _formatDateTime(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}
