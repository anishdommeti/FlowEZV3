import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.joinedQueues,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  final List<String> joinedQueues;

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
    List<String>? joinedQueues,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      joinedQueues: joinedQueues ?? this.joinedQueues,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'customer',
      createdAt: _parseDateTime(map['createdAt']),
      joinedQueues: List<String>.from(map['joinedQueues'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'joinedQueues': joinedQueues,
    };
  }

  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is UserModel &&
        other.uid == uid &&
        other.name == name &&
        other.email == email &&
        other.role == role &&
        other.createdAt == createdAt &&
        _listEquals(other.joinedQueues, joinedQueues);
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        name.hashCode ^
        email.hashCode ^
        role.hashCode ^
        createdAt.hashCode ^
        joinedQueues.hashCode;
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

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) {
    return true;
  }
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
