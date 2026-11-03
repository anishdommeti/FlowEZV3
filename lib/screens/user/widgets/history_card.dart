import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.queueName,
    required this.tokenNumber,
    required this.completedAt,
    required this.status,
    this.queueType,
    this.duration,
  });

  final String queueName;
  final int tokenNumber;
  final DateTime completedAt;
  final String status;
  final String? queueType;
  final String? duration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedStatus = status.trim().toLowerCase();
    final isCompleted = normalizedStatus == 'completed';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        queueName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Token #$tokenNumber',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(isCompleted ? 'Completed' : 'Cancelled'),
                  avatar: Icon(
                    isCompleted
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HistoryInfoPill(
                  label: 'Completed',
                  value: DateFormat('dd MMM yyyy, hh:mm a').format(completedAt.toLocal()),
                ),
                if (queueType != null && queueType!.isNotEmpty)
                  _HistoryInfoPill(
                    label: 'Queue Type',
                    value: queueType!,
                  ),
                if (duration != null && duration!.isNotEmpty)
                  _HistoryInfoPill(
                    label: 'Duration',
                    value: duration!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryInfoPill extends StatelessWidget {
  const _HistoryInfoPill({
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
          Text(
            value,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
