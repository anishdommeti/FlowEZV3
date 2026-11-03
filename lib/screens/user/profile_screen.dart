import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_components.dart';
import '../../core/constants/dimensions.dart';
import '../../core/routes/app_routes.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/queue_service.dart';
import 'widgets/profile_tile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await context.read<AuthProvider>().signOut();
      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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

  Future<void> _editDisplayName(UserModel user) async {
    final controller = TextEditingController(text: user.name);
    final formKey = GlobalKey<FormState>();

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Edit Display Name'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Display name is required.';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      controller.dispose();
      return;
    }

    try {
      await context.read<UserProvider>().updateProfile(
        user.copyWith(name: controller.text.trim()),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated successfully.')),
      );
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please try again.'),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) {
                      return 'Password is required.';
                    }
                    if (password.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      controller.dispose();
      return;
    }

    try {
      await context.read<UserProvider>().changePassword(controller.text);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } on FirebaseAuthException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'requires-recent-login'
                ? 'Please sign in again before changing your password.'
                : (error.message ?? 'Unable to update password right now.'),
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
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final queueService = context.read<QueueService>();
    final currentUser = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: currentUser == null
            ? const _ProfileMessage(
                icon: Icons.lock_outline,
                title: 'Sign in required',
                message: 'Please sign in to view your profile.',
              )
            : StreamBuilder<UserModel>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .snapshots()
                    .map((snapshot) {
                      final data = snapshot.data();
                      if (!snapshot.exists || data == null) {
                        throw Exception('User profile was not found.');
                      }
                      return UserModel.fromMap(data);
                    }),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (userSnapshot.hasError) {
                    return _ProfileMessage(
                      icon: Icons.error_outline,
                      title: 'Unable to load profile',
                      message: userSnapshot.error.toString(),
                    );
                  }

                  final user = userSnapshot.data;
                  if (user == null) {
                    return const _ProfileMessage(
                      icon: Icons.person_off_outlined,
                      title: 'Profile unavailable',
                      message: 'We could not load your account details.',
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: queueService.watchUserHistorySnapshots(user.uid),
                    builder: (context, historySnapshot) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: queueService.watchCancelledTokensForUser(
                          user.uid,
                        ),
                        builder: (context, cancelledSnapshot) {
                          final completedCount =
                              historySnapshot.data?.docs.length ?? 0;
                          final cancelledCount =
                              cancelledSnapshot.data?.docs.length ?? 0;

                          return ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 760,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 28,
                                                    child: Text(
                                                      user.name.isNotEmpty
                                                          ? user.name[0]
                                                                .toUpperCase()
                                                          : '?',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          user.name,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .headlineSmall,
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          user.email,
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
                                                ],
                                              ),
                                              const SizedBox(height: 24),
                                              ResponsiveMetricGrid(
                                                children: [
                                                  _ProfileMetricCard(
                                                    label: 'Role',
                                                    value: _labelize(user.role),
                                                  ),
                                                  _ProfileMetricCard(
                                                    label: 'Created',
                                                    value:
                                                        DateFormat(
                                                          'dd MMM yyyy',
                                                        ).format(
                                                          user.createdAt
                                                              .toLocal(),
                                                        ),
                                                  ),
                                                  _ProfileMetricCard(
                                                    label: 'Queues Joined',
                                                    value: user
                                                        .joinedQueues
                                                        .length
                                                        .toString(),
                                                  ),
                                                  _ProfileMetricCard(
                                                    label: 'Completed',
                                                    value: completedCount
                                                        .toString(),
                                                  ),
                                                  _ProfileMetricCard(
                                                    label: 'Cancelled',
                                                    value: cancelledCount
                                                        .toString(),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ProfileTile(
                                        icon: Icons.edit_outlined,
                                        title: 'Edit Display Name',
                                        subtitle:
                                            'Update how your name appears in FlowEZ.',
                                        onTap: () => _editDisplayName(user),
                                      ),
                                      ProfileTile(
                                        icon: Icons.password_outlined,
                                        title: 'Change Password',
                                        subtitle:
                                            'Set a new password for your account.',
                                        onTap: _changePassword,
                                      ),
                                      ProfileTile(
                                        icon: Icons.logout_rounded,
                                        title: 'Logout',
                                        subtitle:
                                            'Sign out from this device safely.',
                                        onTap: _logout,
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
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  const _ProfileMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 360),
      padding: const EdgeInsets.all(AppDimensions.cardPadding - 2),
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
              child: Text(value, style: theme.textTheme.titleMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
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

String _labelize(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '-';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
