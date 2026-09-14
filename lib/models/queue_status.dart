import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum QueueStatus { waiting, calling, serving, completed, cancelled, skipped }

extension QueueStatusX on QueueStatus {
  String get label {
    switch (this) {
      case QueueStatus.waiting:
        return 'Menunggu';
      case QueueStatus.calling:
        return 'Dipanggil';
      case QueueStatus.serving:
        return 'Dilayani';
      case QueueStatus.completed:
        return 'Selesai';
      case QueueStatus.cancelled:
        return 'Dibatalkan';
      case QueueStatus.skipped:
        return 'Dilewati';
    }
  }

  Color get color {
    switch (this) {
      case QueueStatus.waiting:
        return AppColors.orange;
      case QueueStatus.calling:
        return AppColors.primary;
      case QueueStatus.serving:
        return AppColors.green;
      case QueueStatus.completed:
        return AppColors.green;
      case QueueStatus.cancelled:
        return AppColors.red;
      case QueueStatus.skipped:
        return AppColors.orange;
    }
  }

  IconData get icon {
    switch (this) {
      case QueueStatus.waiting:
        return Icons.access_time_rounded;
      case QueueStatus.calling:
        return Icons.campaign_rounded;
      case QueueStatus.serving:
        return Icons.support_agent_rounded;
      case QueueStatus.completed:
        return Icons.check_circle_rounded;
      case QueueStatus.cancelled:
        return Icons.cancel_rounded;
      case QueueStatus.skipped:
        return Icons.skip_next_rounded;
    }
  }
}

extension QueueStatusString on String {
  QueueStatus toQueueStatus() {
    return switch (this) {
      'waiting' => QueueStatus.waiting,
      'calling' => QueueStatus.calling,
      'serving' => QueueStatus.serving,
      'completed' => QueueStatus.completed,
      'cancelled' => QueueStatus.cancelled,
      'skipped' => QueueStatus.skipped,
      _ => QueueStatus.waiting,
    };
  }
}
