import 'dart:async';
import 'package:flutter/material.dart';
import 'package:queue_go/services/queue_service.dart';

class OperatorController extends ChangeNotifier {
  final QueueService _queueService = QueueService();

  int _selectedCounterId = 1; // Default Loket 1
  List<dynamic> _queues = [];
  bool _isLoading = false;
  Timer? _timer;

  int get selectedCounterId => _selectedCounterId;
  List<dynamic> get queues => _queues;
  bool get isLoading => _isLoading;

  // Inisialisasi & Start Auto-Refresh 3 Detik
  void init() {
    fetchQueues();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => fetchQueues());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Ganti Loket Aktif
  void setSelectedCounter(int counterId) {
    _selectedCounterId = counterId;
    notifyListeners();
  }

  // Refresh Data Antrean Hari Ini
  Future<void> fetchQueues() async {
    try {
      _queues = await _queueService.getQueuesToday();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetchQueues: $e');
    }
  }

  // === EXECUTOR FUNGSI-FUNGSI AKSI OPERATOR ===
  Future<void> handleAction(String action, int paramId) async {
    _isLoading = true;
    notifyListeners();

    try {
      switch (action) {
        case 'call': // Panggil Antrean Selanjutnya
          await _queueService.callNext(paramId);
          break;
        case 'recall': // Panggil Ulang
          await _queueService.recallQueue(paramId);
          break;
        case 'serve': // Mulai Melayani
          await _queueService.serveQueue(paramId);
          break;
        case 'complete': // Selesai Melayani
          await _queueService.completeQueue(paramId);
          break;
        case 'skip': // Lewati Antrean
          await _queueService.skipQueue(paramId);
          break;
      }
      // Refresh Data setelah aksi berhasil
      await fetchQueues();
    } catch (e) {
      debugPrint('Error Action $action: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // === DATA CALCULATED / DERIVED STATE ===

  // 1. Antrean yang Sedang Aktif Dipanggil/Dilayani di Loket Ini
  dynamic get currentActiveQueue {
    try {
      return _queues.firstWhere((q) {
        final int cId = int.parse(q['counter_id'].toString());
        final String status = q['status'].toString();
        return cId == _selectedCounterId && (status == 'calling' || status == 'serving');
      });
    } catch (_) {
      return null;
    }
  }

  // 2. Daftar Sisa Antrean Menunggu di Loket Ini
  List<dynamic> get waitingQueues {
    return _queues.where((q) {
      final int cId = int.parse(q['counter_id'].toString());
      final String status = q['status'].toString();
      return cId == _selectedCounterId && status == 'waiting';
    }).toList();
  }

  // 3. Jumlah Antrean Selesai Hari Ini di Loket Ini
  int get completedCount {
    return _queues.where((q) {
      final int cId = int.parse(q['counter_id'].toString());
      return cId == _selectedCounterId && q['status'] == 'completed';
    }).length;
  }

  // 4. Jumlah Antrean Dilewati Hari Ini di Loket Ini
  int get skippedCount {
    return _queues.where((q) {
      final int cId = int.parse(q['counter_id'].toString());
      return cId == _selectedCounterId && q['status'] == 'skipped';
    }).length;
  }
}