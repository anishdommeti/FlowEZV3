import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_components.dart';

import '../../core/constants/dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../models/queue_model.dart';
import '../../models/token_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../services/queue_service.dart';

class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key, required this.queue});

  final QueueModel queue;

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_startStreams);
  }

  Future<void> _startStreams() async {
    final authProvider = context.read<AuthProvider>();
    final queueProvider = context.read<QueueProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null || userId.isEmpty) {
      return;
    }

    await queueProvider.watchQueue(widget.queue.queueId);
    await queueProvider.watchUserToken(
      queueId: widget.queue.queueId,
      userId: userId,
    );
  }

  Future<void> _refresh() async {
    await _startStreams();
  }

  Future<void> _cancelToken(TokenModel token) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;

    if (userId == null || userId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please sign in to manage your token.')),
      );
      return;
    }

    try {
      await context.read<QueueProvider>().cancelToken(
        tokenId: token.tokenId,
        userId: userId,
      );
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Your token has been cancelled.')),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final queueProvider = context.watch<QueueProvider>();
    final queueService = context.read<QueueService>();
    final userId = authProvider.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Token'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
          ),
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
              ? const _TokenMessage(
                  icon: Icons.lock_outline,
                  title: 'Sign in required',
                  message: 'Please sign in to view your live token status.',
                )
              : StreamBuilder<QueueModel>(
                  stream: queueService.watchQueue(widget.queue.queueId),
                  builder: (context, queueSnapshot) {
                    return StreamBuilder<TokenModel?>(
                      stream: queueService.watchLatestTokenForUser(
                        queueId: widget.queue.queueId,
                        userId: userId,
                      ),
                      builder: (context, tokenSnapshot) {
                        if (queueSnapshot.connectionState ==
                                ConnectionState.waiting ||
                            tokenSnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (queueSnapshot.hasError) {
                          return _TokenMessage(
                            icon: Icons.cloud_off_outlined,
                            title: 'Unable to load queue',
                            message: queueSnapshot.error.toString(),
                          );
                        }

                        if (tokenSnapshot.hasError) {
                          return _TokenMessage(
                            icon: Icons.error_outline,
                            title: 'Unable to load token',
                            message: tokenSnapshot.error.toString(),
                          );
                        }

                        final queue = queueSnapshot.data;
                        final token = tokenSnapshot.data;

                        if (queue == null) {
                          return const _TokenMessage(
                            icon: Icons.inbox_outlined,
                            title: 'Queue unavailable',
                            message: 'This queue is no longer available.',
                          );
                        }

                        final queueIsOpen = _isQueueOpen(queue.status);

                        if (token == null) {
                          return _TokenMessage(
                            icon: Icons.confirmation_number_outlined,
                            title: 'No active token',
                            message:
                                'You do not currently have an active token for ${queue.name}.',
                          );
                        }

                        final tokenStatus = token.status.toLowerCase();
                        final hasActiveToken =
                            tokenStatus == 'waiting' || tokenStatus == 'called';
                        final peopleAhead = hasActiveToken
                            ? queueProvider.peopleAhead(
                                queue: queue,
                                token: token,
                              )
                            : 0;
                        final estimatedWait = hasActiveToken
                            ? queueProvider.estimatedWait(
                                queue: queue,
                                token: token,
                              )
                            : 0;
                        final completionMessage = switch (tokenStatus) {
                          'completed' =>
                            'Your token has been completed. Thank you for using FlowEZ.',
                          'cancelled' =>
                            'This token was cancelled and is no longer active.',
                          'called' => 'Please proceed now. It is your turn.',
                          _ => 'Your token is active and waiting in the queue.',
                        };

                        return ListView(
                          padding: const EdgeInsets.all(
                            AppDimensions.pagePadding,
                          ),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(
                                          AppDimensions.cardPadding,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        queue.name,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineSmall,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        queue
                                                                .description
                                                                .isEmpty
                                                            ? 'Live queue updates are active.'
                                                            : queue.description,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.copyWith(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    _StatusBadge(
                                                      status: token.status,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Chip(
                                                      label: Text(
                                                        queueIsOpen
                                                            ? 'Queue Open'
                                                            : 'Queue Closed',
                                                      ),
                                                      avatar: Icon(
                                                        queueIsOpen
                                                            ? Icons
                                                                  .lock_open_rounded
                                                            : Icons
                                                                  .lock_outline_rounded,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.45),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                completionMessage,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge,
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  AppDimensions.sectionSpacing,
                                            ),
                                            Center(
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 180,
                                                      maxWidth: 320,
                                                    ),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal:
                                                            AppDimensions
                                                                .cardPadding,
                                                        vertical: 28,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppDimensions
                                                              .buttonRadius,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        'Your Token',
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.labelLarge,
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        token.tokenNumber
                                                            .toString(),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .displaySmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              height:
                                                  AppDimensions.sectionSpacing,
                                            ),
                                            ResponsiveMetricGrid(
                                              children: [
                                                _TokenMetricCard(
                                                  label: 'Current Token',
                                                  value: queue.currentToken
                                                      .toString(),
                                                ),
                                                _TokenMetricCard(
                                                  label: 'People Ahead',
                                                  value: peopleAhead.toString(),
                                                ),
                                                _TokenMetricCard(
                                                  label: 'Current Position',
                                                  value: hasActiveToken
                                                      ? queueProvider
                                                            .currentPosition(
                                                              queue: queue,
                                                              token: token,
                                                            )
                                                            .toString()
                                                      : '-',
                                                ),
                                                _TokenMetricCard(
                                                  label: 'Queue Status',
                                                  value: queueIsOpen
                                                      ? 'Open'
                                                      : 'Closed',
                                                ),
                                                _TokenMetricCard(
                                                  label: 'Token Status',
                                                  value: _labelize(
                                                    token.status,
                                                  ),
                                                ),
                                                _TokenMetricCard(
                                                  label: 'Estimated Wait',
                                                  value: estimatedWait == 0
                                                      ? (hasActiveToken
                                                            ? 'No wait'
                                                            : '-')
                                                      : '$estimatedWait mins',
                                                ),
                                              ],
                                            ),
                                            if (tokenStatus == 'waiting') ...[
                                              const SizedBox(
                                                height: AppDimensions
                                                    .sectionSpacing,
                                              ),
                                              SizedBox(
                                                width: double.infinity,
                                                height:
                                                    AppDimensions.buttonHeight,
                                                child: FilledButton.tonalIcon(
                                                  onPressed: () =>
                                                      _cancelToken(token),
                                                  icon: const Icon(
                                                    Icons.cancel_outlined,
                                                  ),
                                                  label: const Text(
                                                    'Cancel Token',
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppDimensions
                                                                .buttonRadius,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
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
      ),
    );
  }
}

String _labelize(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '-';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

bool _isQueueOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final theme = Theme.of(context);

    Color color;
    switch (normalized) {
      case 'called':
        color = theme.colorScheme.primary;
      case 'completed':
        color = Colors.green;
      case 'cancelled':
        color = theme.colorScheme.error;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized[0].toUpperCase() + normalized.substring(1),
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TokenMetricCard extends StatelessWidget {
  const _TokenMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 156,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Text(value, style: theme.textTheme.titleLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenMessage extends StatelessWidget {
  const _TokenMessage({
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
