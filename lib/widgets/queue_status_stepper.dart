import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/queue_status.dart';

/// Stepper 4 Tahap Visual Real-time untuk Antrean Pelanggan:
/// Menunggu -> Dipanggil -> Dilayani -> Selesai
class QueueStatusStepper extends StatelessWidget {
  final QueueStatus status;

  const QueueStatusStepper({
    super.key,
    required this.status,
  });

  int get currentStep {
    switch (status) {
      case QueueStatus.waiting:
        return 0;
      case QueueStatus.calling:
        return 1;
      case QueueStatus.serving:
        return 2;
      case QueueStatus.completed:
        return 3;
      case QueueStatus.skipped:
      case QueueStatus.cancelled:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = currentStep;
    final isCancelledOrSkipped = activeIndex == -1;

    final steps = [
      {'title': 'Menunggu', 'icon': Icons.hourglass_top_rounded},
      {'title': 'Dipanggil', 'icon': Icons.campaign_rounded},
      {'title': 'Dilayani', 'icon': Icons.support_agent_rounded},
      {'title': 'Selesai', 'icon': Icons.check_circle_rounded},
    ];

    if (isCancelledOrSkipped) {
      final label = status == QueueStatus.cancelled ? 'Dibatalkan' : 'Dilewati';
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.red, size: 22),
            const SizedBox(width: 8),
            Text(
              'Status Antrean: $label',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isDone = index < activeIndex;
          final isCurrent = index == activeIndex;
          final icon = steps[index]['icon'] as IconData;
          final title = steps[index]['title'] as String;

          Color itemColor;
          if (isDone) {
            itemColor = AppColors.green;
          } else if (isCurrent) {
            itemColor = status == QueueStatus.calling
                ? AppColors.green
                : (status == QueueStatus.serving
                    ? AppColors.green
                    : AppColors.orange);
          } else {
            itemColor = Colors.grey[300]!;
          }

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isCurrent ? 36 : 30,
                        height: isCurrent ? 36 : 30,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.green.withOpacity(0.15)
                              : isCurrent
                                  ? itemColor.withOpacity(0.15)
                                  : Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: itemColor,
                            width: isCurrent ? 2.5 : 1.5,
                          ),
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : icon,
                          size: isCurrent ? 18 : 14,
                          color: itemColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCurrent ? 11 : 10,
                          fontWeight: isCurrent || isDone
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isDone
                              ? AppColors.textDark
                              : isCurrent
                                  ? itemColor
                                  : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 10,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: index < activeIndex ? AppColors.green : Colors.grey[200],
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
