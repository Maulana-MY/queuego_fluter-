import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/counter_model.dart';
import '../../models/queue_model.dart';
import '../../models/queue_status.dart';
import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';
import '../../services/storage_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/queue_status_stepper.dart';

/// Layar status antrean realtime untuk USER (mobile)
/// Menampilkan nomor antrean, status, posisi di depan, dan auto-refresh setiap 5 detik
class StatusAntreanScreen extends StatefulWidget {
  final Queue queue;
  final Counter counter;

  const StatusAntreanScreen({
    super.key,
    required this.queue,
    required this.counter,
  });

  @override
  State<StatusAntreanScreen> createState() => _StatusAntreanScreenState();
}

class _StatusAntreanScreenState extends State<StatusAntreanScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  Timer? _refreshTimer;
  late Queue _currentQueue;
  int _aheadCount = 0;
  bool _isLoading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentQueue = widget.queue;
    _saveQueueLocally();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fetchStatus();
    // Auto-refresh setiap 5 detik
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchStatus();
    });
  }

  void _saveQueueLocally() {
    StorageService.saveActiveQueue(_currentQueue);
  }

  Future<void> _speakCall(String number, String counterName, {bool isRecall = false}) async {
    await TtsService().speakQueueCall(
      queueId: _currentQueue.id,
      queueNumber: number,
      counterName: counterName,
      isRecall: isRecall,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    if (_isLoading) return;
    try {
      final allQueues = await _apiService.getQueuesToday();
      if (!mounted) return;

      // Temukan antrean kita berdasarkan ID
      final updated = allQueues.where((q) => q.id == _currentQueue.id);
      if (updated.isNotEmpty) {
        final newQueue = updated.first;
        final oldStatus = _currentQueue.status;
        final oldCalledAt = _currentQueue.calledAt;

        final ahead = allQueues
            .where((q) =>
                q.counterId == _currentQueue.counterId &&
                q.status == QueueStatus.waiting &&
                q.id < _currentQueue.id)
            .length;

        setState(() {
          _currentQueue = newQueue;
          _aheadCount = ahead;
        });

        // Suara pengumuman saat dipanggil atau panggil ulang (recall)
        final bool isRecall = newQueue.status == QueueStatus.calling &&
            oldCalledAt != null &&
            newQueue.calledAt != null &&
            newQueue.calledAt!.isAfter(oldCalledAt);

        final bool isFirstCall =
            oldStatus != QueueStatus.calling && newQueue.status == QueueStatus.calling;

        if (isFirstCall) {
          _speakCall(newQueue.queueNumber, widget.counter.name, isRecall: false);
        } else if (isRecall) {
          _speakCall(newQueue.queueNumber, widget.counter.name, isRecall: true);
        }

        // Simpan atau bersihkan penyimpanan lokal
        if (newQueue.status == QueueStatus.completed ||
            newQueue.status == QueueStatus.cancelled ||
            newQueue.status == QueueStatus.skipped) {
          StorageService.clearActiveQueue();
        } else {
          StorageService.saveActiveQueue(newQueue);
        }
      }
    } catch (_) {
      // Gagal refresh diam-diam
    }
  }

  Color _statusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
        return AppColors.orange;
      case QueueStatus.calling:
        return AppColors.primary;
      case QueueStatus.serving:
        return AppColors.green;
      case QueueStatus.completed:
        return AppColors.green;
      case QueueStatus.skipped:
        return AppColors.red;
      case QueueStatus.cancelled:
        return AppColors.red;
    }
  }

  String _statusMessage(QueueStatus status) {
    switch (status) {
      case QueueStatus.waiting:
        return 'Antrean Anda sedang menunggu. Harap tetap di area tunggu.';
      case QueueStatus.calling:
        return 'GILIRAN ANDA! Silakan menuju ke ${widget.counter.name} sekarang.';
      case QueueStatus.serving:
        return 'Anda sedang dilayani di ${widget.counter.name}.';
      case QueueStatus.completed:
        return 'Pelayanan Anda telah selesai. Terima kasih!';
      case QueueStatus.skipped:
        return 'Antrean Anda dilewati. Silakan hubungi petugas.';
      case QueueStatus.cancelled:
        return 'Antrean Anda telah dibatalkan.';
    }
  }

  bool get _isFinished =>
      _currentQueue.status == QueueStatus.completed ||
      _currentQueue.status == QueueStatus.skipped ||
      _currentQueue.status == QueueStatus.cancelled;

  Future<void> _cancelQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Batalkan Antrean?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan antrean nomor ${_currentQueue.queueNumber}? Anda dapat mengambil antrean baru setelah ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.skipQueue(_currentQueue.id);
      } catch (_) {}
      await StorageService.clearActiveQueue();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Antrean ${_currentQueue.queueNumber} berhasil dibatalkan.'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_currentQueue.status);
    final isCalling = _currentQueue.status == QueueStatus.calling;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: const Text(
          'Status Antrean',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: _fetchStatus,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchStatus,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // =========================================
                  // KARTU NOMOR ANTREAN (HERO)
                  // =========================================
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = isCalling
                          ? 1.0 + (_pulseController.value * 0.03)
                          : 1.0;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCalling
                              ? [AppColors.green, const Color(0xFF059669)]
                              : [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: (isCalling ? AppColors.green : AppColors.primary)
                                .withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            isCalling ? '🔔 GILIRAN ANDA!' : 'NOMOR ANTREAN ANDA',
                            style: const TextStyle(
                              color: Colors.white70,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            child: Text(
                              _currentQueue.queueNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.counter.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // =========================================
                  // TAHAPAN STATUS VISUAL STEPPER
                  // =========================================
                  QueueStatusStepper(status: _currentQueue.status),
                  const SizedBox(height: 14),

                  // =========================================
                  // STATUS BADGE
                  // =========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(_currentQueue.status.icon,
                            color: statusColor, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${_currentQueue.status.label}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _statusMessage(_currentQueue.status),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: statusColor.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // =========================================
                  // DETAIL INFO
                  // =========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _infoRow(Icons.person_outline, 'Nama',
                            _currentQueue.customerName),
                        const Divider(height: 20),
                        _infoRow(Icons.access_time_rounded, 'Waktu Ambil',
                            formatDate(_currentQueue.createdAt)),
                        if (_currentQueue.calledAt != null) ...[
                          const Divider(height: 20),
                          _infoRow(Icons.campaign_rounded, 'Waktu Dipanggil',
                              formatDate(_currentQueue.calledAt!)),
                        ],
                        if (_currentQueue.completedAt != null) ...[
                          const Divider(height: 20),
                          _infoRow(Icons.check_circle_rounded, 'Waktu Selesai',
                              formatDate(_currentQueue.completedAt!)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // =========================================
                  // QUEUE PROGRESS WIDGET
                  // =========================================
                  if (!_isFinished)
                    QueueProgressWidget(
                      aheadCount: _aheadCount,
                      status: _currentQueue.status,
                    ),
                  const SizedBox(height: 20),

                  // =========================================
                  // TOMBOL KEMBALI & BATAL
                  // =========================================
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _isFinished ? AppColors.primary : Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(
                        _isFinished ? 'Kembali ke Beranda' : 'Kembali',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                  if (_currentQueue.status == QueueStatus.waiting) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _cancelQueue,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text(
                          'Batalkan Antrean',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Live indicator
                  if (!_isFinished)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.green.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live • Auto-refresh setiap 5 detik',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: valueColor ?? AppColors.textGrey, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textGrey)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// QUEUE PROGRESS WIDGET
// ============================================================

/// Widget reusable yang menampilkan jumlah antrean di depan
/// dan progress bar visual
class QueueProgressWidget extends StatelessWidget {
  final int aheadCount;
  final QueueStatus status;

  const QueueProgressWidget({
    super.key,
    required this.aheadCount,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isCalling = status == QueueStatus.calling;
    final isServing = status == QueueStatus.serving;

    if (isCalling || isServing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.greenBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isCalling
                  ? Icons.campaign_rounded
                  : Icons.support_agent_rounded,
              size: 32,
              color: AppColors.green,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCalling ? 'Anda Sedang Dipanggil!' : 'Sedang Dilayani',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCalling
                        ? 'Segera menuju ke loket yang ditentukan.'
                        : 'Proses pelayanan sedang berlangsung.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Status: waiting — tampilkan progress
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded,
                  size: 32, color: AppColors.orange),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aheadCount == 0
                          ? 'Anda berikutnya!'
                          : 'Antrean di depan Anda: $aheadCount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Mohon perhatikan layar monitor dan panggilan suara.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (aheadCount > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: aheadCount <= 10
                    ? 1.0 - (aheadCount / 10.0)
                    : 0.05,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  aheadCount <= 2 ? AppColors.green : AppColors.orange,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                aheadCount <= 2
                    ? 'Hampir giliran Anda!'
                    : 'Estimasi ~${aheadCount * 3} menit',
                style: TextStyle(
                  fontSize: 10,
                  color: aheadCount <= 2
                      ? AppColors.green
                      : AppColors.textFaint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
