import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/dimensions.dart';
import '../../core/widgets/app_components.dart';
import '../../core/routes/app_routes.dart';
import '../../models/queue_model.dart';
import '../../models/token_model.dart';
import '../../providers/queue_provider.dart';
import '../../services/queue_service.dart';

class ManageQueueScreen extends StatelessWidget {
  const ManageQueueScreen({super.key, required this.queue});

  final QueueModel queue;

  @override
  Widget build(BuildContext context) {
    final queueService = context.read<QueueService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Queue')),
      body: SafeArea(
        child: StreamBuilder<QueueModel>(
          stream: queueService.watchQueue(queue.queueId),
          builder: (context, queueSnapshot) {
            if (queueSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (queueSnapshot.hasError) {
              return _ManageStateMessage(
                icon: Icons.error_outline,
                title: 'Unable to load queue',
                message: queueSnapshot.error.toString(),
              );
            }

            final currentQueue = queueSnapshot.data;
            if (currentQueue == null) {
              return const _ManageStateMessage(
                icon: Icons.inbox_outlined,
                title: 'Queue unavailable',
                message: 'This queue no longer exists.',
              );
            }

            return StreamBuilder<List<TokenModel>>(
              stream: queueService.watchQueueProgress(currentQueue.queueId),
              builder: (context, tokenSnapshot) {
                final tokens = tokenSnapshot.data ?? const <TokenModel>[];
                final waitingUsers = tokens
                    .where((token) => token.status.toLowerCase() == 'waiting')
                    .toList();
                TokenModel? currentCalledToken;
                for (final token in tokens) {
                  if (token.status.toLowerCase() == 'called') {
                    currentCalledToken = token;
                    break;
                  }
                }
                final queueIsOpen = _isOpen(currentQueue.status);

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        Text(
                                          currentQueue.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                        Chip(
                                          label: Text(
                                            _isOpen(currentQueue.status)
                                                ? 'Open'
                                                : 'Closed',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      currentQueue.description.isEmpty
                                          ? 'No description available.'
                                          : currentQueue.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    ResponsiveMetricGrid(
                                      children: [
                                        _ManageMetric(
                                          label: 'Current Token',
                                          value: currentQueue.currentToken
                                              .toString(),
                                        ),
                                        _ManageMetric(
                                          label: 'Last Token',
                                          value: currentQueue.lastToken
                                              .toString(),
                                        ),
                                        _ManageMetric(
                                          label: 'Waiting Users',
                                          value: waitingUsers.length.toString(),
                                        ),
                                        _ManageMetric(
                                          label: 'Called Token',
                                          value:
                                              currentCalledToken?.tokenNumber
                                                  .toString() ??
                                              '-',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Consumer<QueueProvider>(
                              builder: (context, queueProvider, _) {
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    FilledButton.icon(
                                      onPressed:
                                          queueProvider.isLoading ||
                                              !queueIsOpen ||
                                              currentCalledToken != null
                                          ? null
                                          : () => _callNext(
                                              context,
                                              queueProvider,
                                              currentQueue.queueId,
                                            ),
                                      icon: const Icon(
                                        Icons.notifications_active_outlined,
                                      ),
                                      label: const Text('Call Next'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed:
                                          queueProvider.isLoading ||
                                              currentCalledToken == null
                                          ? null
                                          : () => _completeCurrentToken(
                                              context,
                                              queueProvider,
                                              currentQueue.queueId,
                                            ),
                                      icon: const Icon(Icons.task_alt_rounded),
                                      label: const Text('Complete Current'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          queueProvider.isLoading || queueIsOpen
                                          ? null
                                          : () => _reopenQueue(
                                              context,
                                              queueProvider,
                                              currentQueue.queueId,
                                            ),
                                      icon: const Icon(Icons.lock_open_rounded),
                                      label: const Text('Reopen Queue'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed:
                                          queueProvider.isLoading ||
                                              !queueIsOpen
                                          ? null
                                          : () => _closeQueue(
                                              context,
                                              queueProvider,
                                              currentQueue.queueId,
                                            ),
                                      icon: const Icon(
                                        Icons.lock_outline_rounded,
                                      ),
                                      label: const Text('Close Queue'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () =>
                                          Navigator.of(context).pushNamed(
                                            AppRoutes.queueQr,
                                            arguments: currentQueue,
                                          ),
                                      icon: const Icon(Icons.qr_code_2_rounded),
                                      label: const Text('Queue QR'),
                                    ),
                                    TextButton.icon(
                                      onPressed: queueProvider.isLoading
                                          ? null
                                          : () => _deleteQueue(
                                              context,
                                              queueProvider,
                                              currentQueue.queueId,
                                            ),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Delete Queue'),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Queue Progress',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    if (tokenSnapshot.connectionState ==
                                        ConnectionState.waiting)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(24),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (tokenSnapshot.hasError)
                                      Text(tokenSnapshot.error.toString())
                                    else if (tokens.isEmpty)
                                      Text(
                                        'No active tokens are currently in this queue.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      )
                                    else
                                      ...tokens.map(
                                        (token) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            child: Text(
                                              token.tokenNumber.toString(),
                                            ),
                                          ),
                                          title: Text(
                                            'Token ${token.tokenNumber}',
                                          ),
                                          subtitle: Text(
                                            'Status: ${token.status}',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _callNext(
    BuildContext context,
    QueueProvider queueProvider,
    String queueId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final token = await queueProvider.callNext(queueId);
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Token ${token.tokenNumber} has been called.')),
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _reopenQueue(
    BuildContext context,
    QueueProvider queueProvider,
    String queueId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await queueProvider.reopenQueue(queueId);
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Queue reopened successfully.')),
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _closeQueue(
    BuildContext context,
    QueueProvider queueProvider,
    String queueId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await queueProvider.closeQueue(queueId);
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Queue closed successfully.')),
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _completeCurrentToken(
    BuildContext context,
    QueueProvider queueProvider,
    String queueId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final token = await queueProvider.completeToken(queueId);
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Token ${token.tokenNumber} marked as completed.'),
        ),
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteQueue(
    BuildContext context,
    QueueProvider queueProvider,
    String queueId,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Queue'),
              content: const Text(
                'This will permanently delete the queue and its related live queue records.',
              ),
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

    if (!confirmed || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await queueProvider.deleteQueue(queueId);
      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queue deleted successfully.')),
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _ManageMetric extends StatelessWidget {
  const _ManageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 140,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.smallRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(value, style: theme.textTheme.headlineSmall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageStateMessage extends StatelessWidget {
  const _ManageStateMessage({
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
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.titleLarge),
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
    );
  }
}

bool _isOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}
