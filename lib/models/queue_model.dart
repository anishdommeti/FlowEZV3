import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class QueueModel {
  const QueueModel({
    required this.queueId,
    required this.name,
    required this.description,
    required this.status,
    required this.currentToken,
    required this.lastToken,
    required this.createdBy,
    required this.createdAt,
  });

  final String queueId;
  final String name;
  final String description;
  final String status;
  final int currentToken;
  final int lastToken;
  final String createdBy;
  final DateTime createdAt;

  QueueModel copyWith({
    String? queueId,
    String? name,
    String? description,
    String? status,
    int? currentToken,
    int? lastToken,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return QueueModel(
      queueId: queueId ?? this.queueId,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      currentToken: currentToken ?? this.currentToken,
      lastToken: lastToken ?? this.lastToken,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory QueueModel.fromMap(Map<String, dynamic> map) {
    return QueueModel(
      queueId: map['queueId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'inactive',
      currentToken: (map['currentToken'] as num? ?? 0).toInt(),
      lastToken: (map['lastToken'] as num? ?? 0).toInt(),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'queueId': queueId,
      'name': name,
      'description': description,
      'status': status,
      'currentToken': currentToken,
      'lastToken': lastToken,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory QueueModel.fromJson(String source) =>
      QueueModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is QueueModel &&
        other.queueId == queueId &&
        other.name == name &&
        other.description == description &&
        other.status == status &&
        other.currentToken == currentToken &&
        other.lastToken == lastToken &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return queueId.hashCode ^
        name.hashCode ^
        description.hashCode ^
        status.hashCode ^
        currentToken.hashCode ^
        lastToken.hashCode ^
        createdBy.hashCode ^
        createdAt.hashCode;
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
