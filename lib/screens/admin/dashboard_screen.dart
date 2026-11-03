import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_components.dart';
import '../../core/constants/dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../models/queue_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../services/queue_service.dart';
import 'widgets/admin_queue_card.dart';
import 'widgets/dashboard_stat_card.dart';
import 'create_queue_screen.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<void> _refresh() async {
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await context.read<AuthProvider>().signOut();
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(content: Text('No internet connection. Please try again.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _createQueue() async {
    final created = await Navigator.of(context).push(
  MaterialPageRoute<bool>(
    builder: (_) => const CreateQueueScreen(),
  ),
);

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queue created successfully.')),
      );
    }
  }

  Future<void> _manageQueue(QueueModel queue) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.manageQueue,
      arguments: queue,
    );
  }

  Future<void> _setQueueStatus(QueueModel queue, bool isOpen) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await context.read<QueueProvider>().setQueueStatus(
            queueId: queue.queueId,
            isOpen: isOpen,
          );
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(isOpen ? '${queue.name} is now open.' : '${queue.name} is now closed.'),
        ),
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(content: Text('No internet connection. Please try again.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteQueue(QueueModel queue) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Queue'),
              content: Text('Delete ${queue.name} and its related queue records?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await context.read<QueueProvider>().deleteQueue(queue.queueId);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('${queue.name} deleted successfully.')),
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(content: Text('No internet connection. Please try again.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueService = context.read<QueueService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowEZ Admin'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.analytics),
            tooltip: 'Analytics',
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createQueue,
        icon: const Icon(Icons.add),
        label: const Text('Create Queue'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: queueService.watchQueueSnapshots(),
            builder: (context, queueSnapshot) {
              if (queueSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (queueSnapshot.hasError) {
                return _DashboardMessage(
                  icon: Icons.error_outline,
                  title: 'Unable to load dashboard',
                  message: queueSnapshot.error.toString(),
                );
              }

              final queues = queueSnapshot.data?.docs
                      .map((document) => QueueModel.fromMap(document.data()))
                      .toList() ??
                  const <QueueModel>[];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('tokens')
                    .where('status', isEqualTo: 'waiting')
                    .snapshots(),
                builder: (context, waitingSnapshot) {
                  final waitingDocs = waitingSnapshot.data?.docs ?? const [];
                  final waitingByQueue = <String, int>{};
                  for (final document in waitingDocs) {
                    final data = document.data();
                    final queueId = data['queueId'] as String? ?? '';
                    waitingByQueue.update(
                      queueId,
                      (value) => value + 1,
                      ifAbsent: () => 1,
                    );
                  }

                  final activeQueues =
                      queues.where((queue) => _isOpen(queue.status)).length;
                  final closedQueues = queues.length - activeQueues;
                  final totalWaiting = waitingDocs.length;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.pagePadding,
                            AppDimensions.pagePadding,
                            AppDimensions.pagePadding,
                            AppDimensions.pagePadding / 2,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {

                              final stats = [
                                DashboardStatCard(
                                  title: 'Active Queues',
                                  value: queues.length.toString(),
                                  icon: Icons.view_list_rounded,
                                ),
                                DashboardStatCard(
                                  title: 'Open Queues',
                                  value: activeQueues.toString(),
                                  icon: Icons.lock_open_rounded,
                                ),
                                DashboardStatCard(
                                  title: 'Closed Queues',
                                  value: closedQueues.toString(),
                                  icon: Icons.lock_outline_rounded,
                                ),
                                DashboardStatCard(
                                  title: 'Total Waiting Users',
                                  value: totalWaiting.toString(),
                                  icon: Icons.groups_rounded,
                                ),
                              ];

                              return ResponsiveMetricGrid(
  children: stats,
);
                            },
                          ),
                        ),
                      ),
                      if (queues.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _DashboardMessage(
                            icon: Icons.inbox_outlined,
                            title: 'No queues created yet',
                            message:
                                'Create your first queue to begin managing live flow.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppDimensions.pagePadding,
                            AppDimensions.cardSpacing / 2,
                            AppDimensions.pagePadding,
                            AppDimensions.pagePadding * 5,
                          ),
                          sliver: SliverList.separated(
                            itemBuilder: (context, index) {
                              final queue = queues[index];
                              return AdminQueueCard(
                                queue: queue,
                                waitingCount: waitingByQueue[queue.queueId] ?? 0,
                                onManage: () => _manageQueue(queue),
                                onOpen: () => _setQueueStatus(queue, true),
                                onClose: () => _setQueueStatus(queue, false),
                                onDelete: () => _deleteQueue(queue),
                              );
                            },
                            separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.cardSpacing),
                            itemCount: queues.length,
                          ),
                        ),
                    ],
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

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: AppDimensions.sectionSpacing),
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppDimensions.cardSpacing / 2.5),
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

bool _isOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}
