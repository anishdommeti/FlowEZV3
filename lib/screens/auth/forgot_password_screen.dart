import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await context
          .read<AuthProvider>()
          .resetPassword(_emailController.text.trim());

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reset email sent'),
            content: Text(
              'A password reset email has been sent to ${_emailController.text.trim()}.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } on FirebaseAuthException catch (error) {
      _showErrorSnackBar(_mapFirebaseAuthException(error));
    } on SocketException {
      _showErrorSnackBar(
        'No internet connection. Please check your network and try again.',
      );
    } catch (error) {
      _showErrorSnackBar(error.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.mark_email_read_outlined,
                              size: 52,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reset your password',
                              style: theme.textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your email and we will send you a reset link.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: _validateEmail,
                              onFieldSubmitted: (_) =>
                                  authProvider.isLoading ? null : _submit(),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed:
                                  authProvider.isLoading ? null : _submit,
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Send reset email'),
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

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Email is required.';
  }

  const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
  if (!RegExp(emailPattern).hasMatch(email)) {
    return 'Enter a valid email address.';
  }

  return null;
}

String _mapFirebaseAuthException(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'The email address is not valid.';
    case 'user-not-found':
      return 'No account was found for this email.';
    case 'network-request-failed':
      return 'Network error. Please check your connection and try again.';
    default:
      return error.message ?? 'Unable to send reset email right now.';
  }
}
