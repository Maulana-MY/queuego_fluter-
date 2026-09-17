import 'dart:async';
import 'package:flutter/material.dart';
import '../models/counter_model.dart';
import '../models/queue_model.dart';
import '../models/queue_status.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';

class QueueProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final TtsService _ttsService = TtsService();

  List<Counter> _counters = [];
  List<Queue> _queues = [];
  Queue? _myQueue;
  int _selectedCounterId = 1;
  bool _isLoading = false;
  Timer? _pollingTimer;

  bool get hasActiveTicket {
    if (_myQueue == null) return false;
    final s = _myQueue!.status;
    return s == QueueStatus.waiting || s == QueueStatus.calling || s == QueueStatus.serving;
  }

  List<Counter> get counters => _counters;
  List<Queue> get queues => _queues;
  Queue? get myQueue => _myQueue;
  int get selectedCounterId => _selectedCounterId;
  bool get isLoading => _isLoading;

  QueueProvider() {
    _loadSavedActiveQueue();
    fetchInitialData();
    startPolling();
  }

  Future<void> _loadSavedActiveQueue() async {
    final saved = await StorageService.getActiveQueue();
    if (saved != null) {
      _myQueue = saved;
      notifyListeners();
    }
  }

  Future<void> fetchInitialData() async {
    _isLoading = true;
    notifyListeners();
    await refreshData();
    _isLoading = false;
    notifyListeners();
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => silentRefresh());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  @override
  void dispose() {
    stopPolling();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> refreshData() async {
    try {
      final apiCounters = await _apiService.getCounters();
      if (apiCounters.isNotEmpty) _counters = apiCounters;
      _queues = await _apiService.getQueuesToday();
      _updateMyTicketFromList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing: $e');
    }
  }

  Future<void> silentRefresh() async {
    try {
      _queues = await _apiService.getQueuesToday();
      _updateMyTicketFromList();

      if (_myQueue != null && _myQueue!.status == QueueStatus.calling) {
        final counter = _counters.firstWhere(
          (c) => c.id == _myQueue!.counterId,
          orElse: () => Counter(id: _myQueue!.counterId, name: 'Loket ${_myQueue!.counterId}'),
        );
        _ttsService.speakQueueCall(
          queueId: _myQueue!.id,
          queueNumber: _myQueue!.queueNumber,
          counterName: counter.name,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  void _updateMyTicketFromList() {
    if (_myQueue == null) return;
    final updated = _queues.where((q) => q.id == _myQueue!.id);
    if (updated.isNotEmpty) {
      _myQueue = updated.first;
      StorageService.saveActiveQueue(_myQueue!);
      if (_myQueue!.status == QueueStatus.completed ||
          _myQueue!.status == QueueStatus.skipped ||
          _myQueue!.status == QueueStatus.cancelled) {
        StorageService.clearActiveQueue();
      }
    }
  }

  Future<Queue?> takeQueue(int counterId, String name) async {
    final clean = name.trim().isEmpty ? 'Pelanggan' : name.trim();
    final q = await _apiService.createQueue(counterId: counterId, customerName: clean);
    _myQueue = q;
    StorageService.saveActiveQueue(q);
    await refreshData();
    return q;
  }

  Future<void> cancelMyActiveQueue() async {
    if (_myQueue == null) return;
    await _apiService.skipQueue(_myQueue!.id);
    _myQueue = null;
    await StorageService.clearActiveQueue();
    await refreshData();
  }

  // Operator Actions (100% SILENT as per specification)
  Future<Queue?> callNextQueue(int counterId) async {
    final waiting = _queues.where((q) => q.counterId == counterId && q.status == QueueStatus.waiting).toList();
    waiting.sort((a, b) => a.id.compareTo(b.id));
    if (waiting.isEmpty) return null;
    final called = await _apiService.callQueue(counterId);
    await refreshData();
    return called;
  }

  Future<Queue> recallQueue(int queueId) async {
    final q = await _apiService.recallQueue(queueId);
    await refreshData();
    return q;
  }

  Future<Queue> serveQueue(int queueId) async {
    final q = await _apiService.serveQueue(queueId);
    await refreshData();
    return q;
  }

  Future<Queue> completeQueue(int queueId) async {
    final q = await _apiService.completeQueue(queueId);
    await refreshData();
    return q;
  }

  Future<Queue> skipQueue(int queueId) async {
    final q = await _apiService.skipQueue(queueId);
    await refreshData();
    return q;
  }

  int queuesAhead(Queue q) => _queues.where((item) => item.counterId == q.counterId && item.status == QueueStatus.waiting && item.id < q.id).length;

  // Jumlah antrean waiting untuk counter tertentu (used by operator panel button condition)
  int get waitingQueuesCount => _queues.where((q) => q.counterId == _selectedCounterId && q.status == QueueStatus.waiting).length;

  // Antrean waiting untuk counter tertentu
  int getWaitingCount(int cid) => _queues.where((q) => q.counterId == cid && q.status == QueueStatus.waiting).length;

  // Antrean selesai hari ini (last 24 jam)
  int getCompletedCount(int cid) => _queues.where((q) {
        if (q.counterId != cid || q.status != QueueStatus.completed) return false;
        return _isWithinLast24h(q.createdAt);
      }).length;

  // Antrean dilewati hari ini (last 24 jam)
  int getSkippedCount(int cid) => _queues.where((q) {
        if (q.counterId != cid || q.status != QueueStatus.skipped) return false;
        return _isWithinLast24h(q.createdAt);
      }).length;

  bool _isWithinLast24h(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.isAfter(now.subtract(const Duration(hours: 24)));
  }

  Queue? getActiveQueueForCounter(int cid) {
    final active = _queues.where((q) => q.counterId == cid && (q.status == QueueStatus.calling || q.status == QueueStatus.serving)).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.id.compareTo(a.id));
    return active.first;
  }

  double getAverageServiceDuration() {
    final done = _queues.where((q) => q.status == QueueStatus.completed).toList();
    if (done.isEmpty) return 0.0;
    double total = 0.0;
    int count = 0;
    for (var q in done) {
      if (q.calledAt != null && q.completedAt != null) {
        total += q.completedAt!.difference(q.calledAt!).inSeconds / 60.0;
        count++;
      }
    }
    return count == 0 ? 0.0 : total / count;
  }

  void setSelectedCounter(int counterId) {
    if (_selectedCounterId == counterId) return;
    _selectedCounterId = counterId;
    notifyListeners();
  }
}
