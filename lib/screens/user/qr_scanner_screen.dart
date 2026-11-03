import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../services/qr_service.dart';
import '../../services/queue_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isHandlingScan = false;
  String? _cameraError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isHandlingScan) {
      return;
    }

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    _isHandlingScan = true;

    try {
      const qrService = QRService();
      final queueService = context.read<QueueService>();
      final payload = qrService.parsePayload(rawValue);
      final queueId = payload['queueId'] as String?;

      if (queueId == null || queueId.trim().isEmpty) {
        throw const QRServiceException('The scanned QR code does not contain a valid queue ID.');
      }

      final queue = await queueService.getQueueById(queueId.trim());

      if (!mounted) {
        return;
      }

      await _controller.stop();

      if (!mounted) {
        return;
      }

      await Navigator.of(context).pushNamed(
        AppRoutes.queueDetails,
        arguments: {
          'queue': queue,
          'showQrSuccessBanner': true,
        },
      );

      if (!mounted) {
        return;
      }

      await _controller.start();
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showInvalidQrDialog(error.toString());
    } finally {
      _isHandlingScan = false;
    }
  }

  Future<void> _showInvalidQrDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Invalid QR Code'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Queue QR'),
      ),
      body: SafeArea(
        child: _cameraError != null
            ? _ScannerStateCard(
                icon: Icons.camera_alt_outlined,
                title: 'Camera unavailable',
                message: _cameraError!,
              )
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: MobileScanner(
                          controller: _controller,
                          onDetect: _handleDetect,
                          errorBuilder: (context, error) {
                            final message = switch (error.errorCode) {
                              MobileScannerErrorCode.permissionDenied =>
                                'Camera permission was denied. Please allow camera access to scan queue QR codes.',
                              MobileScannerErrorCode.unsupported =>
                                'This device does not support camera scanning.',
                              _ => 'The camera could not be started. Please try again.',
                            };

                            scheduleMicrotask(() {
                              if (mounted) {
                                setState(() {
                                  _cameraError = message;
                                });
                              }
                            });

                            return _ScannerStateCard(
                              icon: Icons.camera_alt_outlined,
                              title: 'Camera unavailable',
                              message: message,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Point your camera at a queue QR code to open that queue and review its details before joining.',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ScannerStateCard extends StatelessWidget {
  const _ScannerStateCard({
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
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
