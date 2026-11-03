import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/queue_model.dart';
import '../models/token_model.dart';
import '../services/queue_service.dart';

class QueueProvider extends ChangeNotifier {
  QueueProvider({
    required this.queueService,
  });

  final QueueService queueService;

  StreamSubscription<List<QueueModel>>? _queueSubscription;
  StreamSubscription<List<TokenModel>>? _tokenSubscription;
  StreamSubscription<QueueModel>? _selectedQueueSubscription;
  StreamSubscription<TokenModel?>? _userTokenSubscription;
  List<QueueModel> _queues = const [];
  List<TokenModel> _tokens = const [];
  QueueModel? _selectedQueue;
  TokenModel? _userToken;
  bool _isLoading = false;
  String? _error;

  List<QueueModel> get queues => List.unmodifiable(_queues);
  List<TokenModel> get tokens => List.unmodifiable(_tokens);
  QueueModel? get selectedQueue => _selectedQueue;
  TokenModel? get userToken => _userToken;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> startQueueListener() async {
    _setLoading(true);
    _error = null;

    try {
      await _queueSubscription?.cancel();
      _queueSubscription = queueService.watchQueues().listen(
        (queues) {
          _queues = queues;
          _setLoading(false);
        },
        onError: (Object error) {
          _error = error.toString();
          _setLoading(false);
        },
      );
    } catch (error) {
      _error = error.toString();
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> watchQueueTokens(String queueId) async {
    _setLoading(true);
    _error = null;

    try {
      await _tokenSubscription?.cancel();
      _tokenSubscription = queueService.watchTokensForQueue(queueId).listen(
        (tokens) {
          _tokens = tokens;
          _setLoading(false);
        },
        onError: (Object error) {
          _error = error.toString();
          _setLoading(false);
        },
      );
    } catch (error) {
      _error = error.toString();
      _setLoading(false);
      rethrow;
    }
  }

  Future<QueueModel> createQueue({
    required String name,
    required String description,
    required String createdBy,
    String initialStatus = 'active',
  }) async {
    debugPrint(
      '[QueueProvider] createQueue called with name="$name", createdBy="$createdBy", '
      'initialStatus="$initialStatus"',
    );
    return _execute(
      () => queueService.createQueue(
        name: name,
        description: description,
        createdBy: createdBy,
        initialStatus: initialStatus,
      ),
    );
  }

  Future<TokenModel> joinQueue({
    required String queueId,
    required String userId,
  }) {
    return _execute(
      () => queueService.joinQueue(queueId: queueId, userId: userId),
    );
  }

  Future<void> advanceQueue(String queueId) async {
    await _executeVoid(() => queueService.advanceQueue(queueId));
  }

  Future<TokenModel> callNext(String queueId) {
    return _execute(() => queueService.callNext(queueId));
  }

  Future<TokenModel?> callNextReadyHelpers(String queueId) {
    return _execute(() => queueService.callNextReadyHelpers(queueId));
  }

  Future<TokenModel?> getUserToken({
    required String queueId,
    required String userId,
  }) {
    return _execute(
      () => queueService.getUserToken(queueId: queueId, userId: userId),
    );
  }

  Future<void> watchQueue(String queueId) async {
    _setLoading(true);
    _error = null;

    try {
      await _selectedQueueSubscription?.cancel();
      _selectedQueueSubscription = queueService.watchQueue(queueId).listen(
        (queue) {
          _selectedQueue = queue;
          _setLoading(false);
        },
        onError: (Object error) {
          _error = error.toString();
          _setLoading(false);
        },
      );
    } catch (error) {
      _error = error.toString();
      _setLoading(false);
      rethrow;
    }
  }

  Future<void> watchUserToken({
    required String queueId,
    required String userId,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _userTokenSubscription?.cancel();
      _userTokenSubscription = queueService
          .watchUserToken(queueId: queueId, userId: userId)
          .listen(
        (token) {
          _userToken = token;
          _setLoading(false);
        },
        onError: (Object error) {
          _error = error.toString();
          _setLoading(false);
        },
      );
    } catch (error) {
      _error = error.toString();
      _setLoading(false);
      rethrow;
    }
  }

  int peopleAhead({
    required QueueModel queue,
    required TokenModel token,
  }) {
    return (token.tokenNumber - queue.currentToken - 1).clamp(0, 1 << 31);
  }

  int currentPosition({
    required QueueModel queue,
    required TokenModel token,
  }) {
    return peopleAhead(queue: queue, token: token) + 1;
  }

  int estimatedWait({
    required QueueModel queue,
    required TokenModel token,
  }) {
    return peopleAhead(queue: queue, token: token) * 2;
  }

  Future<void> cancelToken({
    required String tokenId,
    required String userId,
  }) async {
    await _executeVoid(
      () => queueService.cancelToken(tokenId: tokenId, userId: userId),
    );
  }

  Future<TokenModel> completeToken(String queueId) {
    return _execute(() => queueService.completeCurrentToken(queueId));
  }

  Future<void> setQueueStatus({
    required String queueId,
    required bool isOpen,
  }) async {
    await _executeVoid(
      () => queueService.setQueueStatus(queueId: queueId, isOpen: isOpen),
    );
  }

  Future<void> reopenQueue(String queueId) async {
    await _executeVoid(() => queueService.reopenQueue(queueId));
  }

  Future<void> closeQueue(String queueId) async {
    await _executeVoid(() => queueService.closeQueue(queueId));
  }

  Future<void> deleteQueue(String queueId) async {
    await _executeVoid(() => queueService.deleteQueue(queueId));
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<T> _execute<T>(Future<T> Function() action) async {
    debugPrint('[QueueProvider] _execute start');
    _setLoading(true);
    _error = null;
    try {
      final result = await action();
      debugPrint('[QueueProvider] _execute success');
      return result;
    } catch (error) {
      _error = error.toString();
      debugPrint('[QueueProvider] _execute caught error: $error');
      rethrow;
    } finally {
      debugPrint('[QueueProvider] _execute finally; clearing loading');
      _setLoading(false);
    }
  }

  Future<void> _executeVoid(Future<void> Function() action) async {
    debugPrint('[QueueProvider] _executeVoid start');
    _setLoading(true);
    _error = null;
    try {
      await action();
      debugPrint('[QueueProvider] _executeVoid success');
    } catch (error) {
      _error = error.toString();
      debugPrint('[QueueProvider] _executeVoid caught error: $error');
      rethrow;
    } finally {
      debugPrint('[QueueProvider] _executeVoid finally; clearing loading');
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _tokenSubscription?.cancel();
    _selectedQueueSubscription?.cancel();
    _userTokenSubscription?.cancel();
    super.dispose();
  }
}
