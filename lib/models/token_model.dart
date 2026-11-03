import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class TokenModel {
  const TokenModel({
    required this.tokenId,
    required this.queueId,
    required this.userId,
    required this.tokenNumber,
    required this.status,
    required this.joinedAt,
  });

  final String tokenId;
  final String queueId;
  final String userId;
  final int tokenNumber;
  final String status;
  final DateTime joinedAt;

  TokenModel copyWith({
    String? tokenId,
    String? queueId,
    String? userId,
    int? tokenNumber,
    String? status,
    DateTime? joinedAt,
  }) {
    return TokenModel(
      tokenId: tokenId ?? this.tokenId,
      queueId: queueId ?? this.queueId,
      userId: userId ?? this.userId,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory TokenModel.fromMap(Map<String, dynamic> map) {
    return TokenModel(
      tokenId: map['tokenId'] as String? ?? '',
      queueId: map['queueId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      tokenNumber: (map['tokenNumber'] as num? ?? 0).toInt(),
      status: map['status'] as String? ?? 'waiting',
      joinedAt: _parseDateTime(map['joinedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tokenId': tokenId,
      'queueId': queueId,
      'userId': userId,
      'tokenNumber': tokenNumber,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory TokenModel.fromJson(String source) =>
      TokenModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is TokenModel &&
        other.tokenId == tokenId &&
        other.queueId == queueId &&
        other.userId == userId &&
        other.tokenNumber == tokenNumber &&
        other.status == status &&
        other.joinedAt == joinedAt;
  }

  @override
  int get hashCode {
    return tokenId.hashCode ^
        queueId.hashCode ^
        userId.hashCode ^
        tokenNumber.hashCode ^
        status.hashCode ^
        joinedAt.hashCode;
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
