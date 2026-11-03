import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  const NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;

  NotificationModel copyWith({
    String? notificationId,
    String? userId,
    String? title,
    String? message,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      notificationId: map['notificationId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'message': message,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NotificationModel.fromJson(String source) =>
      NotificationModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is NotificationModel &&
        other.notificationId == notificationId &&
        other.userId == userId &&
        other.title == title &&
        other.message == message &&
        other.read == read &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return notificationId.hashCode ^
        userId.hashCode ^
        title.hashCode ^
        message.hashCode ^
        read.hashCode ^
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
