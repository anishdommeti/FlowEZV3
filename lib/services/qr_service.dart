import 'dart:convert';

import '../models/token_model.dart';

class QRService {
  const QRService();

  String buildQueuePayload({
    required String queueId,
    required String queueName,
  }) {
    return jsonEncode({
      'type': 'queue',
      'queueId': queueId,
      'queueName': queueName,
    });
  }

  String buildTokenPayload(TokenModel token) {
    return jsonEncode({
      'type': 'token',
      'tokenId': token.tokenId,
      'queueId': token.queueId,
      'userId': token.userId,
      'tokenNumber': token.tokenNumber,
      'status': token.status,
      'joinedAt': token.joinedAt.toIso8601String(),
    });
  }

  Map<String, dynamic> parsePayload(String rawValue) {
    final parsed = jsonDecode(rawValue);
    if (parsed is! Map<String, dynamic>) {
      throw const QRServiceException('Unsupported QR payload.');
    }
    return parsed;
  }
}

class QRServiceException implements Exception {
  const QRServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
