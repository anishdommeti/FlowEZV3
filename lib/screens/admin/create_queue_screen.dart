import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';

class CreateQueueScreen extends StatefulWidget {
  const CreateQueueScreen({super.key});

  @override
  State<CreateQueueScreen> createState() => _CreateQueueScreenState();
}

class _CreateQueueScreenState extends State<CreateQueueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _queueType = 'General';
  String _initialStatus = 'open';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('[CreateQueueScreen] _submit invoked');
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final isValid = _formKey.currentState!.validate();
    debugPrint('[CreateQueueScreen] form validation result: $isValid');
    if (!isValid) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final queueProvider = context.read<QueueProvider>();
    final userId = authProvider.currentUser?.uid;
    debugPrint('[CreateQueueScreen] authProvider.currentUser: ${authProvider.currentUser}');
    debugPrint('[CreateQueueScreen] resolved userId: $userId');

    if (userId == null || userId.isEmpty) {
      debugPrint('[CreateQueueScreen] userId is null or empty, aborting submit');
      messenger.showSnackBar(
        const SnackBar(content: Text('Admin session is unavailable. Please sign in again.')),
      );
      return;
    }

    try {
      debugPrint(
        '[CreateQueueScreen] calling QueueProvider.createQueue with name="${_nameController.text.trim()}", '
        'queueType="$_queueType", initialStatus="$_initialStatus"',
      );
      await queueProvider.createQueue(
        name: _nameController.text.trim(),
        description:
            '${_queueType.trim()} queue - ${_descriptionController.text.trim()}',
        createdBy: userId,
        initialStatus: _initialStatus,
      );
      debugPrint('[CreateQueueScreen] QueueProvider.createQueue completed successfully');

      if (!mounted) {
        debugPrint('[CreateQueueScreen] widget unmounted before navigation');
        return;
      }

      debugPrint('[CreateQueueScreen] popping screen with success result');
      Navigator.of(context).pop(true);
    } on SocketException {
      debugPrint('[CreateQueueScreen] SocketException while creating queue');
      messenger.showSnackBar(
        const SnackBar(content: Text('No internet connection. Please try again.')),
      );
    } catch (error) {
      debugPrint('[CreateQueueScreen] caught error from createQueue: $error');
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Queue'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Consumer<QueueProvider>(
                    builder: (context, queueProvider, _) {
                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Queue Name',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'Queue name is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                prefixIcon: Icon(Icons.description_outlined),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if ((value?.trim() ?? '').isEmpty) {
                                  return 'Description is required.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _queueType,
                              decoration: const InputDecoration(
                                labelText: 'Queue Type',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'General', child: Text('General')),
                                DropdownMenuItem(value: 'Priority', child: Text('Priority')),
                                DropdownMenuItem(value: 'Express', child: Text('Express')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _queueType = value ?? 'General';
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _initialStatus,
                              decoration: const InputDecoration(
                                labelText: 'Initial Status',
                                prefixIcon: Icon(Icons.toggle_on_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'open', child: Text('Open')),
                                DropdownMenuItem(value: 'closed', child: Text('Closed')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _initialStatus = value ?? 'open';
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: queueProvider.isLoading ? null : _submit,
                              child: queueProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Create Queue'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
