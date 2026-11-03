import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/queue_service.dart';
import 'widgets/history_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<void> _refresh() async {
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final queueService = context.read<QueueService>();
    final userId = authProvider.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: userId == null || userId.isEmpty
              ? const _HistoryMessage(
                  icon: Icons.lock_outline,
                  title: 'Sign in required',
                  message: 'Please sign in to view your queue history.',
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: queueService.watchUserHistorySnapshots(userId),
                  builder: (context, historySnapshot) {
                    if (historySnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (historySnapshot.hasError) {
                      return _HistoryMessage(
                        icon: Icons.error_outline,
                        title: 'Unable to load history',
                        message: historySnapshot.error.toString(),
                      );
                    }

                    final historyDocs = historySnapshot.data?.docs ?? const [];

                    if (historyDocs.isEmpty) {
                      return const _HistoryMessage(
                        icon: Icons.history_outlined,
                        title: 'No completed history yet',
                        message:
                            'Your completed queue visits will appear here automatically.',
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      itemCount: historyDocs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final data = historyDocs[index].data();
                        final completedAt = _parseDateTime(data['completedAt']);
                        final queueName = (data['queueName'] as String?)?.trim();
                        final queueType = (data['queueType'] as String?)?.trim();
                        final durationMinutes = (data['durationMinutes'] as num?)?.toInt();
                        final status =
                            (data['status'] as String?)?.trim().isNotEmpty == true
                                ? data['status'] as String
                                : 'completed';

                        return HistoryCard(
                          queueName: queueName?.isNotEmpty == true
                              ? queueName!
                              : 'Queue ${data['queueId'] ?? ''}',
                          tokenNumber: (data['tokenNumber'] as num? ?? 0).toInt(),
                          completedAt: completedAt,
                          status: status,
                          queueType: queueType,
                          duration: durationMinutes == null
                              ? null
                              : '$durationMinutes mins',
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
