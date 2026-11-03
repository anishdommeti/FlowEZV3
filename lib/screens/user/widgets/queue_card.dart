import 'package:flutter/material.dart';

import '../../../core/constants/dimensions.dart';
import '../../../core/widgets/app_components.dart';
import '../../../models/queue_model.dart';

class QueueCard extends StatelessWidget {
  const QueueCard({
    super.key,
    required this.queue,
    required this.onJoin,
    required this.onDetails,
  });

  final QueueModel queue;
  final VoidCallback onJoin;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = _isQueueOpen(queue.status);
    final waitingCount = (queue.lastToken - queue.currentToken).clamp(0, 1 << 31);

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompact) ...[
                    _QueueCardHeader(
                      queue: queue,
                      isOpen: isOpen,
                    ),
                    const SizedBox(height: 16),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _QueueCardHeader(
                            queue: queue,
                            isOpen: isOpen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _StatusChip(isOpen: isOpen),
                      ],
                    ),
                  if (isCompact)
                    _StatusChip(isOpen: isOpen),
                  const SizedBox(height: 16),
                  Text(
                    queue.description.isEmpty
                        ? 'No description available.'
                        : queue.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ResponsiveMetricGrid(
                    children: [
                      _InfoTile(
                        label: 'Current',
                        value: queue.currentToken.toString(),
                      ),
                      _InfoTile(
                        label: 'Last Issued',
                        value: queue.lastToken.toString(),
                      ),
                      _InfoTile(
                        label: 'Waiting',
                        value: waitingCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDetails,
                          child: const Text('Details'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: isOpen ? onJoin : null,
                          child: const Text('Join Queue'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _isQueueOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}

class _QueueCardHeader extends StatelessWidget {
  const _QueueCardHeader({
    required this.queue,
    required this.isOpen,
  });

  final QueueModel queue;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          queue.name,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          isOpen ? 'Queue is currently accepting participants.' : 'Queue is currently closed.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      avatar: Icon(
        isOpen ? Icons.check_circle_outline : Icons.pause_circle_outline,
        size: 18,
        color: isOpen ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      label: Text(isOpen ? 'Open' : 'Closed'),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 96),
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
          Text(
            value,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
