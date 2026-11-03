import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/app_components.dart';
import '../../models/queue_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';

class QueueDetailsScreen extends StatelessWidget {
  const QueueDetailsScreen({
    super.key,
    required this.queue,
    this.showQrSuccessBanner = false,
  });

  final QueueModel queue;
  final bool showQrSuccessBanner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = _isQueueOpen(queue.status);
    final waitingCount = (queue.lastToken - queue.currentToken).clamp(0, 1 << 31);
    final estimatedWaitMinutes = waitingCount * 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Details'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showQrSuccessBanner) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Queue found successfully from QR. Review the details below before joining.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              queue.name,
                              style: theme.textTheme.headlineSmall,
                            ),
                            StatusChip(
                              label: isOpen ? 'Open' : 'Closed',
                              isOpen: isOpen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          queue.description.isEmpty
                              ? 'No description available for this queue.'
                              : queue.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ResponsiveMetricGrid(
                          children: [
                            MetricCard(
                              label: 'Current Token',
                              value: queue.currentToken.toString(),
                            ),
                            MetricCard(
                              label: 'Last Token',
                              value: queue.lastToken.toString(),
                            ),
                            MetricCard(
                              label: 'People Ahead',
                              value: waitingCount.toString(),
                            ),
                            MetricCard(
                              label: 'Estimated Wait',
                              value: estimatedWaitMinutes == 0
                                  ? 'No wait'
                                  : '$estimatedWaitMinutes mins',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),
                  Consumer2<AuthProvider, QueueProvider>(
                    builder: (context, authProvider, queueProvider, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: AppDimensions.buttonHeight,
                        child: FilledButton.icon(
                          onPressed: (!isOpen || queueProvider.isLoading)
                              ? null
                              : () => _joinQueue(
                                    context,
                                    authProvider: authProvider,
                                    queueProvider: queueProvider,
                                  ),
                          icon: queueProvider.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login_outlined),
                          label: Text(isOpen ? 'Join Queue' : 'Queue Closed'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDimensions.buttonRadius,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.token,
                        arguments: queue,
                      ),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const Text('View Live Token'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.buttonRadius,
                          ),
                        ),
                      ),
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

  Future<void> _joinQueue(
    BuildContext context, {
    required AuthProvider authProvider,
    required QueueProvider queueProvider,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final userId = authProvider.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to join a queue.')),
      );
      return;
    }

    try {
      final token = await queueProvider.joinQueue(
        queueId: queue.queueId,
        userId: userId,
      );

      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You joined ${queue.name}. Your token number is ${token.tokenNumber}.',
          ),
        ),
      );
      Navigator.of(context).pushNamed(
        AppRoutes.token,
        arguments: queue,
      );
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

bool _isQueueOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}
