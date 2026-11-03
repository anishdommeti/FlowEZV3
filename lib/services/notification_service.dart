import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/notification_model.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => NotificationModel.fromMap(document.data()))
              .toList(),
        );
  }

  Future<NotificationModel> createNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    final notificationId = _uuid.v4();
    final notification = NotificationModel(
      notificationId: notificationId,
      userId: userId,
      title: title.trim(),
      message: message.trim(),
      read: false,
      createdAt: DateTime.now().toUtc(),
    );

    await _notifications.doc(notificationId).set(notification.toMap());
    return notification;
  }

  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'read': true});
  }
}
