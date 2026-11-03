import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/queue_model.dart';
import '../models/token_model.dart';

const Set<String> _activeTokenStatuses = {'waiting', 'called'};

class QueueService {
  QueueService({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _queues =>
      _firestore.collection('queues');
  CollectionReference<Map<String, dynamic>> get _tokens =>
      _firestore.collection('tokens');
  CollectionReference<Map<String, dynamic>> get _history =>
      _firestore.collection('history');
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchQueueSnapshots() {
    return _queues.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<List<QueueModel>> watchQueues() {
    return _queues.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((document) => QueueModel.fromMap(document.data()))
              .toList(),
        );
  }

  Stream<QueueModel> watchQueue(String queueId) {
    return _queues.doc(queueId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const QueueServiceException('Queue not found.');
      }

      return QueueModel.fromMap(data);
    });
  }

  Stream<List<TokenModel>> watchQueueProgress(String queueId) {
  return _tokens
      .where('queueId', isEqualTo: queueId)
      //.orderBy('tokenNumber')
      .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => TokenModel.fromMap(document.data()))
              .where((token) => _activeTokenStatuses.contains(token.status.toLowerCase()))
              .toList(),
        );
  }

  Future<QueueModel> getQueueById(String queueId) async {
    final document = await _queues.doc(queueId).get();
    final data = document.data();
    if (!document.exists || data == null) {
      throw const QueueServiceException('Queue not found.');
    }
    return QueueModel.fromMap(data);
  }

  Future<QueueModel> createQueue({
    required String name,
    required String description,
    required String createdBy,
    String initialStatus = 'active',
  }) async {
    debugPrint(
      '[QueueService] createQueue entered with name="$name", createdBy="$createdBy", '
      'initialStatus="$initialStatus"',
    );
    final normalizedName = name.trim().toLowerCase();
    debugPrint('[QueueService] normalizedName="$normalizedName"');
    debugPrint('[QueueService] querying collection "${_queues.path}" for duplicates');
    final duplicateQuery = await _queues
        .where('nameSearchKey', isEqualTo: normalizedName)
        .limit(1)
        .get();
    debugPrint(
      '[QueueService] duplicate query completed; matches=${duplicateQuery.docs.length}',
    );

    if (duplicateQuery.docs.isNotEmpty) {
      debugPrint('[QueueService] duplicate queue found, throwing');
      throw const QueueServiceException('A queue with this name already exists.');
    }

    final queueId = _uuid.v4();
    final queue = QueueModel(
      queueId: queueId,
      name: name.trim(),
      description: description.trim(),
      status: initialStatus,
      currentToken: 0,
      lastToken: 0,
      createdBy: createdBy,
      createdAt: DateTime.now().toUtc(),
    );
    debugPrint('[QueueService] constructed QueueModel: ${queue.toMap()}');

    debugPrint('[QueueService] writing queue document to "${_queues.doc(queueId).path}"');
    await _queues.doc(queueId).set({
      ...queue.toMap(),
      'nameSearchKey': normalizedName,
    });
    debugPrint('[QueueService] Firestore write completed for queueId="$queueId"');
    return queue;
  }

  Future<QueueModel> updateQueue(QueueModel queue) async {
    await _queues.doc(queue.queueId).update({
      ...queue.toMap(),
      'nameSearchKey': queue.name.trim().toLowerCase(),
    });
    return queue;
  }

  Future<void> setQueueStatus({
    required String queueId,
    required bool isOpen,
  }) async {
    await _queues.doc(queueId).update({
      'status': isOpen ? 'open' : 'closed',
    });
  }

  Future<void> reopenQueue(String queueId) {
    return setQueueStatus(queueId: queueId, isOpen: true);
  }

  Future<void> closeQueue(String queueId) {
    return setQueueStatus(queueId: queueId, isOpen: false);
  }

  Future<void> deleteQueue(String queueId) async {
    final queueReference = _queues.doc(queueId);
    final tokensSnapshot = await _tokens.where('queueId', isEqualTo: queueId).get();
    final historySnapshot = await _history.where('queueId', isEqualTo: queueId).get();
    final usersSnapshot = await _users.where('joinedQueues', arrayContains: queueId).get();

    final batch = _firestore.batch();
    batch.delete(queueReference);

    for (final document in tokensSnapshot.docs) {
      batch.delete(document.reference);
    }

    for (final document in historySnapshot.docs) {
      batch.delete(document.reference);
    }

    for (final document in usersSnapshot.docs) {
      final joinedQueues =
          List<String>.from(document.data()['joinedQueues'] as List? ?? const []);
      batch.update(document.reference, {
        'joinedQueues': joinedQueues.where((id) => id != queueId).toList(),
      });
    }

    await batch.commit();
  }

  Future<TokenModel> joinQueue({
    required String queueId,
    required String userId,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final queueReference = _queues.doc(queueId);
      final userReference = _users.doc(userId);
      final queueSnapshot = await transaction.get(queueReference);
      final userSnapshot = await transaction.get(userReference);

      if (!queueSnapshot.exists) {
        throw const QueueServiceException('Queue not found.');
      }
      if (!userSnapshot.exists) {
        throw const QueueServiceException('User profile not found.');
      }

      final queue = QueueModel.fromMap(queueSnapshot.data()!);
      if (!_isQueueOpen(queue.status)) {
        throw const QueueServiceException('Queue is closed.');
      }

      final joinedQueues =
          List<String>.from(userSnapshot.data()?['joinedQueues'] as List? ?? const []);
      if (joinedQueues.contains(queueId)) {
        throw const QueueServiceException('You are already waiting in this queue.');
      }

      final token = generateToken(
        queue: queue,
        queueId: queueId,
        userId: userId,
      );

      transaction.set(_tokens.doc(token.tokenId), token.toMap());
      transaction.update(queueReference, {
        'lastToken': token.tokenNumber,
      });
      transaction.update(userReference, {
        'joinedQueues': {...joinedQueues, queueId}.toList(),
      });

      return token;
    });
  }

  TokenModel generateToken({
    required QueueModel queue,
    required String queueId,
    required String userId,
  }) {
    return TokenModel(
      tokenId: _uuid.v4(),
      queueId: queueId,
      userId: userId,
      tokenNumber: queue.lastToken + 1,
      status: 'waiting',
      joinedAt: DateTime.now().toUtc(),
    );
  }

  Future<TokenModel> callNext(String queueId) async {
    return _firestore.runTransaction((transaction) async {
      final queueReference = _queues.doc(queueId);
      final queueSnapshot = await transaction.get(queueReference);

      if (!queueSnapshot.exists) {
        throw const QueueServiceException('Queue not found.');
      }

      final queue = QueueModel.fromMap(queueSnapshot.data()!);

      if (!_isQueueOpen(queue.status)) {
        throw const QueueServiceException('Queue is closed.');
      }

      final existingCalledQuery = await _tokens
          .where('queueId', isEqualTo: queueId)
          .where('status', isEqualTo: 'called')
          .limit(1)
          .get();

      if (existingCalledQuery.docs.isNotEmpty) {
        throw const QueueServiceException(
          'The current called token must be completed before calling the next user.',
        );
      }

      final tokenQuery = await _tokens
          .where('queueId', isEqualTo: queueId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('tokenNumber')
          .limit(1)
          .get();

      if (tokenQuery.docs.isEmpty) {
        throw const QueueServiceException('No waiting users are available to call.');
      }

      final tokenReference = tokenQuery.docs.first.reference;
      final token = TokenModel.fromMap(tokenQuery.docs.first.data());

      transaction.update(queueReference, {
        'currentToken': token.tokenNumber,
      });
      transaction.update(tokenReference, {
        'status': 'called',
      });

      return token.copyWith(status: 'called');
    });
  }

  Future<void> advanceQueue(String queueId) async {
    await callNext(queueId);
  }

  Stream<List<TokenModel>> watchTokensForQueue(String queueId) {
    return _tokens
        .where('queueId', isEqualTo: queueId)
        .orderBy('tokenNumber')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => TokenModel.fromMap(document.data()))
              .toList(),
        );
  }

  Stream<TokenModel?> watchToken(String tokenId) {
    return _tokens.doc(tokenId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return TokenModel.fromMap(data);
    });
  }

  Stream<TokenModel?> watchUserToken({
    required String queueId,
    required String userId,
  }) {
    return _tokens
        .where('queueId', isEqualTo: queueId)
        .where('userId', isEqualTo: userId)
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      for (final document in snapshot.docs) {
        final token = TokenModel.fromMap(document.data());
        if (_activeTokenStatuses.contains(token.status.toLowerCase())) {
          return token;
        }
      }
      return null;
    });
  }

  Stream<TokenModel?> watchLatestTokenForUser({
    required String queueId,
    required String userId,
  }) {
    return _tokens
        .where('queueId', isEqualTo: queueId)
        .where('userId', isEqualTo: userId)
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return TokenModel.fromMap(snapshot.docs.first.data());
    });
  }

  Future<TokenModel?> getUserToken({
    required String queueId,
    required String userId,
  }) async {
    final snapshot = await _tokens
        .where('queueId', isEqualTo: queueId)
        .where('userId', isEqualTo: userId)
        .orderBy('joinedAt', descending: true)
        .limit(10)
        .get();

    for (final document in snapshot.docs) {
      final token = TokenModel.fromMap(document.data());
      if (_activeTokenStatuses.contains(token.status.toLowerCase())) {
        return token;
      }
    }
    return null;
  }

  Future<void> cancelToken({
    required String tokenId,
    required String userId,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final tokenReference = _tokens.doc(tokenId);
      final tokenSnapshot = await transaction.get(tokenReference);

      if (!tokenSnapshot.exists || tokenSnapshot.data() == null) {
        throw const QueueServiceException('Token not found.');
      }

      final token = TokenModel.fromMap(tokenSnapshot.data()!);
      if (!_activeTokenStatuses.contains(token.status.toLowerCase())) {
        throw const QueueServiceException('This token can no longer be cancelled.');
      }

      final userReference = _users.doc(userId);
      final userSnapshot = await transaction.get(userReference);
      if (!userSnapshot.exists || userSnapshot.data() == null) {
        throw const QueueServiceException('User profile not found.');
      }

      final joinedQueues =
          List<String>.from(userSnapshot.data()?['joinedQueues'] as List? ?? const []);

      transaction.update(tokenReference, {'status': 'cancelled'});
      transaction.update(userReference, {
        'joinedQueues': joinedQueues.where((queueId) => queueId != token.queueId).toList(),
      });
    });
  }

  Future<TokenModel> completeCurrentToken(String queueId) async {
    return _firestore.runTransaction((transaction) async {
      final queueReference = _queues.doc(queueId);
      final queueSnapshot = await transaction.get(queueReference);

      if (!queueSnapshot.exists || queueSnapshot.data() == null) {
        throw const QueueServiceException('Queue not found.');
      }

      final currentTokenQuery = await _tokens
          .where('queueId', isEqualTo: queueId)
          .where('status', isEqualTo: 'called')
          .limit(1)
          .get();

      if (currentTokenQuery.docs.isEmpty) {
        throw const QueueServiceException('No called token is available to complete.');
      }

      final tokenDocument = currentTokenQuery.docs.first;
      final token = TokenModel.fromMap(tokenDocument.data());
      final userReference = _users.doc(token.userId);
      final userSnapshot = await transaction.get(userReference);

      if (!userSnapshot.exists || userSnapshot.data() == null) {
        throw const QueueServiceException('User profile not found.');
      }

      final joinedQueues =
          List<String>.from(userSnapshot.data()?['joinedQueues'] as List? ?? const []);
      final historyId = _uuid.v4();

      transaction.set(_history.doc(historyId), {
        'historyId': historyId,
        'queueId': token.queueId,
        'userId': token.userId,
        'tokenNumber': token.tokenNumber,
        'completedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      });
      transaction.delete(tokenDocument.reference);
      transaction.update(userReference, {
        'joinedQueues': joinedQueues.where((queueId) => queueId != token.queueId).toList(),
      });

      return token.copyWith(status: 'completed');
    });
  }

  Future<TokenModel?> callNextReadyHelpers(String queueId) => callNext(queueId);

  Stream<List<TokenModel>> watchTokensForUser(String userId) {
    return _tokens
        .where('userId', isEqualTo: userId)
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => TokenModel.fromMap(document.data()))
              .toList(),
        );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserHistorySnapshots(
    String userId,
  ) {
    return _history
        .where('userId', isEqualTo: userId)
        .orderBy('completedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCancelledTokensForUser(
    String userId,
  ) {
    return _tokens
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'cancelled')
        .snapshots();
  }

  Future<int> totalWaitingUsers() async {
    final snapshot = await _tokens.where('status', isEqualTo: 'waiting').get();
    return snapshot.docs.length;
  }
}

class QueueServiceException implements Exception {
  const QueueServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool _isQueueOpen(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'open' || normalized == 'active';
}
