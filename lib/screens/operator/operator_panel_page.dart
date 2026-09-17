import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/queue_status.dart';
import '../../providers/queue_provider.dart';

class OperatorPanelPage extends StatefulWidget {
  const OperatorPanelPage({super.key});

  @override
  State<OperatorPanelPage> createState() => _OperatorPanelPageState();
}

class _OperatorPanelPageState extends State<OperatorPanelPage>
    with SingleTickerProviderStateMixin {
  Timer? _autoSyncTimer;
  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startAutoSync();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startAutoSync() {
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final provider = context.read<QueueProvider>();
      provider.silentRefresh();
    });
  }

  Future<void> _refreshData() async {
    final provider = context.read<QueueProvider>();
    await provider.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          appBar: AppBar(
            title: const Text(
              'Panel Operator',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textDark,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.border, height: 1),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                onPressed: _refreshData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(provider),
                  const SizedBox(height: 16),
                  _buildMainQueueDisplay(provider),
                  const SizedBox(height: 16),
                  _buildActionButtons(provider),
                  const SizedBox(height: 16),
                  _buildStatisticsCards(provider),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────── HEADER ───────────────
  Widget _buildHeader(QueueProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'PANEL OPERATOR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: provider.counters.map((counter) {
              final isSelected = counter.id == provider.selectedCounterId;
              return Expanded(
                child: GestureDetector(
                  onTap: () => provider.setSelectedCounter(counter.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      counter.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? AppColors.primary : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────── DISPLAY ANTREAN AKTIF ───────────────
  Widget _buildMainQueueDisplay(QueueProvider provider) {
    final activeQueue = provider.getActiveQueueForCounter(provider.selectedCounterId);
    final hasActiveQueue = activeQueue != null;
    final queueNumber = activeQueue?.queueNumber ?? '---';
    final customerName = activeQueue?.customerName ?? '-';
    final status = activeQueue?.status ?? QueueStatus.waiting;

    // Tentukan warna & label berdasarkan status
    final statusColor = {
      QueueStatus.waiting: AppColors.orange,
      QueueStatus.calling: AppColors.purple,
      QueueStatus.serving: AppColors.green,
      QueueStatus.completed: AppColors.green,
      QueueStatus.skipped: AppColors.red,
      QueueStatus.cancelled: AppColors.textGrey,
    }[status]!;

    // Gunakan label Bahasa Indonesia dari extension
    final statusLabel = hasActiveQueue ? status.label.toUpperCase() : 'MENUNGGU';
    final statusIcon = hasActiveQueue ? status.icon : Icons.access_time_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Nomor antrean besar
          if (hasActiveQueue)
            ScaleTransition(
              scale: status == QueueStatus.calling ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
              child: Text(
                queueNumber,
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: 4,
                  height: 1,
                ),
              ),
            )
          else
            Column(
              children: [
                Icon(Icons.inbox_rounded, size: 56, color: AppColors.textGrey.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada antrean aktif',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textGrey.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),

          if (hasActiveQueue) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────── TOMBOL AKSI ───────────────
  Widget _buildActionButtons(QueueProvider provider) {
    final activeQueue = provider.getActiveQueueForCounter(provider.selectedCounterId);
    final hasActiveQueue = activeQueue != null;
    final isCalling = activeQueue?.status == QueueStatus.calling;
    final isServing = activeQueue?.status == QueueStatus.serving;
    final hasWaiting = provider.waitingQueuesCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.textGrey),
              const SizedBox(width: 6),
              const Text(
                'AKSI OPERATOR',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGrey,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Tidak ada antrean aktif: tampilkan tombol Panggil Selanjutnya ──
          if (!hasActiveQueue) ...[
            _buildCallNextButton(
              hasWaiting: hasWaiting,
              waitingCount: provider.waitingQueuesCount,
              onPressed: hasWaiting
                  ? () async {
                      setState(() => _isLoading = true);
                      await provider.callNextQueue(provider.selectedCounterId);
                      if (mounted) setState(() => _isLoading = false);
                    }
                  : null,
            ),
          ],

          // ── Status CALLING: Panggil Ulang + Mulai Layani + Lewati ──
          if (hasActiveQueue && isCalling) ...[
            _buildFullWidthActionButton(
              label: 'PANGGIL ULANG',
              icon: Icons.replay_rounded,
              color: AppColors.purple,
              isLoading: _isLoading,
              onPressed: () async {
                setState(() => _isLoading = true);
                await provider.recallQueue(activeQueue.id);
                if (mounted) setState(() => _isLoading = false);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildActionButton(
                    label: 'MULAI LAYANI',
                    icon: Icons.support_agent_rounded,
                    color: AppColors.primary,
                    isLoading: _isLoading,
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await provider.serveQueue(activeQueue.id);
                      if (mounted) setState(() => _isLoading = false);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    label: 'LEWATI',
                    icon: Icons.skip_next_rounded,
                    color: AppColors.red,
                    isLoading: _isLoading,
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await provider.skipQueue(activeQueue.id);
                      if (mounted) setState(() => _isLoading = false);
                    },
                  ),
                ),
              ],
            ),
          ],

          // ── Status SERVING: Selesai + Lewati ──
          if (hasActiveQueue && isServing) ...[
            _buildFullWidthActionButton(
              label: 'SELESAI DILAYANI',
              icon: Icons.check_circle_rounded,
              color: AppColors.green,
              isLoading: _isLoading,
              onPressed: () async {
                setState(() => _isLoading = true);
                await provider.completeQueue(activeQueue.id);
                if (mounted) setState(() => _isLoading = false);
              },
            ),
            const SizedBox(height: 10),
            _buildFullWidthActionButton(
              label: 'LEWATI',
              icon: Icons.skip_next_rounded,
              color: AppColors.red,
              isLoading: _isLoading,
              isOutlined: true,
              onPressed: () async {
                setState(() => _isLoading = true);
                await provider.skipQueue(activeQueue.id);
                if (mounted) setState(() => _isLoading = false);
              },
            ),
          ],
        ],
      ),
    );
  }

  // Tombol Panggil Selanjutnya (disabled dengan info saat tidak ada antrian)
  Widget _buildCallNextButton({
    required bool hasWaiting,
    required int waitingCount,
    required VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: hasWaiting
                  ? const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: hasWaiting ? null : const Color(0xFFE2E8F0),
              boxShadow: hasWaiting
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : onPressed,
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: hasWaiting ? Colors.white : AppColors.textGrey,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'PANGGIL ANTREAN SELANJUTNYA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: hasWaiting ? Colors.white : AppColors.textGrey,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        if (!hasWaiting) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.textGrey.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'Tidak ada antrean yang menunggu',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$waitingCount antrean menunggu',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFullWidthActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback? onPressed,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: (isLoading || onPressed == null) ? null : onPressed,
              icon: Icon(icon, color: color, size: 20),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: (isLoading || onPressed == null) ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Icon(icon, color: Colors.white, size: 20),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 3,
                shadowColor: color.withValues(alpha: 0.4),
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: (isLoading || onPressed == null) ? null : onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
          shadowColor: color.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ─────────────── STATISTIK ───────────────
  Widget _buildStatisticsCards(QueueProvider provider) {
    final counterId = provider.selectedCounterId;
    final waitingCount = provider.getWaitingCount(counterId);
    final completedCount = provider.getCompletedCount(counterId);
    final skippedCount = provider.getSkippedCount(counterId);
    final avgDuration = provider.getAverageServiceDuration();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.textGrey),
              const SizedBox(width: 6),
              const Text(
                'STATISTIK LOKET HARI INI',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGrey,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Menunggu',
                  value: '$waitingCount',
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Selesai',
                  value: '$completedCount',
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.skip_next_rounded,
                  label: 'Dilewati',
                  value: '$skippedCount',
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer_rounded,
                  label: 'Rata-rata',
                  value: '${avgDuration.toStringAsFixed(1)} mnt',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
}