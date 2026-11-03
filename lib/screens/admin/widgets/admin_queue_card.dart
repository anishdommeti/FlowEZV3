import 'package:flutter/material.dart';

import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/app_components.dart';
import '../../../models/queue_model.dart';

class AdminQueueCard extends StatelessWidget {
  const AdminQueueCard({
    super.key,
    required this.queue,
    required this.waitingCount,
    required this.onManage,
    required this.onOpen,
    required this.onClose,
    required this.onDelete,
  });

  final QueueModel queue;
  final int waitingCount;
  final VoidCallback onManage;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = _isOpen(queue.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        queue.name,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        queue.description.isEmpty
                            ? 'No description available.'
                            : queue.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(isOpen ? 'Open' : 'Closed'),
                  avatar: Icon(
                    isOpen
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ResponsiveMetricGrid(
              children: [
                _AdminInfoPill(
                  label: 'Current Token',
                  value: queue.currentToken.toString(),
                ),
                _AdminInfoPill(
                  label: 'Last Token',
                  value: queue.lastToken.toString(),
                ),
                _AdminInfoPill(
                  label: 'Waiting Users',
                  value: waitingCount.toString(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Manage'),
                ),
                OutlinedButton.icon(
                  onPressed: isOpen ? null : onOpen,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Open'),
                ),
                OutlinedButton.icon(
                  onPressed: isOpen ? onClose : null,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Close'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminInfoPill extends StatelessWidget {
  const _AdminInfoPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

bool _isOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}
