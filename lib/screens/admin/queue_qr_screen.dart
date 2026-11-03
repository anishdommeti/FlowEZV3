import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'dart:ui' as ui;

import '../../core/constants/dimensions.dart';
import '../../core/widgets/app_components.dart';
import '../../models/queue_model.dart';

class QueueQrScreen extends StatelessWidget {
  const QueueQrScreen({
    super.key,
    required this.queue,
  });

  final QueueModel queue;
  
  static final GlobalKey _qrKey = GlobalKey();
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = _isQueueOpen(queue.status);
    final qrPayload = jsonEncode({
      'queueId': queue.queueId,
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue QR'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        Text(
                          queue.name,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        StatusChip(
                          label: isOpen ? 'Open' : 'Closed',
                          isOpen: isOpen,
                        ),
                        const SizedBox(height: AppDimensions.sectionSpacing),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              padding: const EdgeInsets.all(AppDimensions.cardPadding),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 24,
                                    color: Colors.black.withValues(alpha: 0.06),
                                  ),
                                ],
                              ),
                              child: RepaintBoundary(
  key: _qrKey,
  child: Container(
    color: Colors.white,
    padding: const EdgeInsets.all(12),
    child: PrettyQrView.data(
      data: qrPayload,
      decoration: const PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(),
      ),
    ),
  ),
),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.sectionSpacing),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDimensions.cardPadding),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(AppDimensions.smallRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Queue ID',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                queue.queueId,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          messenger.hideCurrentSnackBar();
                          final bytes = await _capturePng();
                          if (bytes == null || bytes.isEmpty) {
                            messenger.showSnackBar(const SnackBar(content: Text('Failed to capture QR image.')));
                            return;
                          }

                          final dir = await getTemporaryDirectory();
                          final file = await File('${dir.path}/${queue.queueId}.png').writeAsBytes(bytes);

                          final shareText = '${queue.name}\nQueue ID: ${queue.queueId}';
                          await SharePlus.instance.share(
                            ShareParams(
                              text: shareText,
                              subject: queue.name,
                              sharePositionOrigin: Rect.zero,
                              files: [XFile(file.path)],
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Share failed: ${e.toString()}')));
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share QR'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          messenger.hideCurrentSnackBar();
                          final bytes = await _capturePng();

                          if (bytes == null || bytes.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to capture QR image.'),
                              ),
                            );
                            return;
                          }

                          final dir = await getTemporaryDirectory();
                          final file = await File(
                            '${dir.path}/${queue.queueId}.png',
                          ).writeAsBytes(bytes);

                          if (!await Gal.hasAccess()) {
                            final granted = await Gal.requestAccess();
                            if (!granted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Gallery permission denied.'),
                                ),
                              );
                              return;
                            }
                          }

                          await Gal.putImage(
                            file.path,
                            album: 'FlowEZ',
                          );

                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('QR code saved to Gallery'),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Save failed: $e'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save QR to Gallery'),
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
}

bool _isQueueOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}

Future<Uint8List?> _capturePng() async {
  try {
    // Wait until the widget is fully painted
    await Future.delayed(const Duration(milliseconds: 100));

    final boundary = QueueQrScreen._qrKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) return null;

    if (boundary.debugNeedsPaint) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final image = await boundary.toImage(
      pixelRatio: 4.0,
    );

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) return null;

    return byteData.buffer.asUint8List();
  } catch (e) {
    debugPrint("QR Capture Error: $e");
    return null;
  }
}
