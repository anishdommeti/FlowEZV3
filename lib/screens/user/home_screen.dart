import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../models/queue_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../services/queue_service.dart';
import 'widgets/queue_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<void> _joinQueue(QueueModel queue) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final authProvider = context.read<AuthProvider>();
    final queueProvider = context.read<QueueProvider>();
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

      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You joined ${queue.name}. Your token number is ${token.tokenNumber}.',
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queueService = context.read<QueueService>();
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(Icons.qr_code_2_rounded),
        ),
        title: const Text(AppStrings.appName),
        titleSpacing: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.qrScanner),
            tooltip: 'Scan QR',
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
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
          const ThemeToggleButton(),
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: queueService.watchQueueSnapshots(),
            builder: (context, snapshot) {
              final queues = snapshot.hasData
                  ? snapshot.data!.docs
                      .map((document) => QueueModel.fromMap(document.data()))
                      .where(_matchesSearch)
                      .toList()
                  : const <QueueModel>[];

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pagePadding,
                        AppDimensions.pagePadding,
                        AppDimensions.pagePadding,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome${currentUser?.name.isNotEmpty == true ? ', ${currentUser!.name}' : ''}',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Find an active queue, review live progress, and join in a few taps.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SearchBar(
                            controller: _searchController,
                            hintText: 'Search queues',
                            trailing: const [
                              Tooltip(
                                message: 'Search available queues',
                                child: Icon(Icons.manage_search_rounded),
                              ),
                            ],
                            leading: const Icon(Icons.search),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.trim().toLowerCase();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _StateMessage(
                        icon: Icons.cloud_off_outlined,
                        title: 'Unable to load queues',
                        message: snapshot.error.toString(),
                      ),
                    )
                  else if (queues.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _StateMessage(
                        icon: Icons.inbox_outlined,
                        title: _searchQuery.isEmpty ? 'No queues available' : 'No matching queues',
                        message: _searchQuery.isEmpty
                            ? 'Live queue listings will appear here when they are available.'
                            : 'Try a different queue name or description.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.pagePadding,
                        8,
                        AppDimensions.pagePadding,
                        AppDimensions.pagePadding,
                      ),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final queue = queues[index];
                          return QueueCard(
                            queue: queue,
                            onJoin: () => _joinQueue(queue),
                            onDetails: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.queueDetails,
                                arguments: queue,
                              );
                            },
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemCount: queues.length,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  bool _matchesSearch(QueueModel queue) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final combined = '${queue.name} ${queue.description}'.toLowerCase();
    return combined.contains(_searchQuery);
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
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
    );
  }
}
